#!/bin/bash

# Configuration
BASE_DIR="$HOME/.ssh/sshps"
SSH_CONFIG="$HOME/.ssh/config"
SSH_KNOWN_HOSTS="$HOME/.ssh/known_hosts"
CURRENT_PROFILE_FILE="$BASE_DIR/current_profile"
SCRIPT_NAME="sshps"
TMP_VALIDATION_FILE="/tmp/ssh_config_validation"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# Supported key types
SUPPORTED_KEY_TYPES=("rsa" "ed25519" "ecdsa" "dsa")
DEFAULT_KEY_TYPE="rsa"
DEFAULT_KEY_SIZE="4096"

# Create base dir
if ! install -d -m 700 -o "$USER" "$BASE_DIR" 2>/dev/null; then
    echo -e "${RED}Error: Failed to create secure directory ${BASE_DIR}${NC}" >&2
    exit 1
fi

# Check profile name
is_valid_profile_name() {
    [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]] && [[ ! "$1" =~ ^- ]] && [[ ! "$1" =~ ^[0-9]+$ ]]
}

# Check and fix permissions
fix_file_permissions() {
    local file="$1" 
    local expected_perm="600"
    local current_perm=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null)
    
    [[ "$current_perm" =~ ^[0-9]{3}$ ]] || { echo -e "${RED}Error: Could not determine permissions for $file${NC}"; return 1; }
    [ "$current_perm" == "$expected_perm" ] && return 0
    
    echo -e "${YELLOW}Warning: Fixing permissions for $file (from $current_perm to $expected_perm)${NC}"
    chmod "$expected_perm" "$file" || { echo -e "${RED}Error: Failed to change permissions for $file${NC}"; return 1; }
}

# Validate ssh config
validate_ssh_config() {
    [ ! -f "$1" ] && { echo -e "${YELLOW}Warning: Config file does not exist${NC}"; return 0; }
    ssh -G -F "$1" localhost > "$TMP_VALIDATION_FILE" 2>&1 && return 0
    
    echo -e "${RED}Error: Invalid SSH config file${NC}"
    grep -i error "$TMP_VALIDATION_FILE" | head -n 5
    return 1
}

# Check and add key to ssh-agent
add_key_to_ssh_agent() {
    local key_path="$1"
    
    # Check if key file exists and is readable
    if [ ! -f "$key_path" ] || [ ! -r "$key_path" ]; then
        echo -e "${YELLOW}Warning: Key file not found or not readable: ${key_path}${NC}"
        return 1
    fi
    
    # Check if ssh-agent is running
    if [ -z "$SSH_AUTH_SOCK" ]; then
        echo -e "${YELLOW}Warning: ssh-agent is not running. Key won't be added.${NC}"
        echo -e "${YELLOW}You can start it with: eval \$(ssh-agent)${NC}"
        return 1
    fi
    
    # Get key fingerprint (more reliable method)
    local key_fingerprint
    if ! key_fingerprint=$(ssh-keygen -lf "$key_path" 2>/dev/null | awk '{print $2}'); then
        echo -e "${RED}Error: Failed to get key fingerprint for ${key_path}${NC}"
        return 1
    fi
    
    # Check if key is already added (reliable version)
    if ssh-add -l >/dev/null 2>&1; then
        local added_keys
        added_keys=$(ssh-add -l | awk '{print $2}')
        if echo "$added_keys" | grep -qF "$key_fingerprint"; then
            echo -e "${CYAN}Key already added to ssh-agent${NC}"
            return 0
        fi
    fi
    
    # Add the key
    echo -e "${CYAN}Adding SSH key to agent...${NC}"
    if ssh-add "$key_path"; then
        echo -e "${GREEN}✓ Added key to ssh-agent: ${key_path}${NC}"
        return 0
    else
        echo -e "${RED}Error: Failed to add key to ssh-agent${NC}"
        return 1
    fi
}

# Generate SSH key with type and size selection
generate_ssh_key() {
    local key_path="${1}/${2}"
    local key_type="${3:-$DEFAULT_KEY_TYPE}"
    local key_size="${4:-$DEFAULT_KEY_SIZE}"
    local key_passphrase="$5"
    
    [ -f "$key_path" ] && { echo -e "${YELLOW}Key already exists at ${key_path}${NC}"; return 0; }

    echo -e "${CYAN}Generating new SSH key (Type: ${key_type}, Size: ${key_size})...${NC}"
    
    # Special handling for ed25519 which has fixed size
    if [ "$key_type" == "ed25519" ]; then
        if [ -n "$key_passphrase" ]; then
            ssh-keygen -t "$key_type" -f "$key_path" -N "$key_passphrase" || { echo -e "${RED}Error: Failed to generate SSH key${NC}"; return 1; }
        else
            ssh-keygen -t "$key_type" -f "$key_path" -N "" || { echo -e "${RED}Error: Failed to generate SSH key${NC}"; return 1; }
        fi
    else
        if [ -n "$key_passphrase" ]; then
            ssh-keygen -t "$key_type" -b "$key_size" -f "$key_path" -N "$key_passphrase" || { echo -e "${RED}Error: Failed to generate SSH key${NC}"; return 1; }
        else
            ssh-keygen -t "$key_type" -b "$key_size" -f "$key_path" -N "" || { echo -e "${RED}Error: Failed to generate SSH key${NC}"; return 1; }
        fi
    fi
    
    echo -e "${GREEN}✓ SSH key generated at ${key_path}${NC}"
    fix_file_permissions "$key_path"
    fix_file_permissions "${key_path}.pub"
}

# Get current profile
get_current_profile() {
    [ -f "$CURRENT_PROFILE_FILE" ] && cat "$CURRENT_PROFILE_FILE"
}

# Pretty separator
print_separator() {
    echo -e "${BLUE}--------------------------------------------------${NC}"
}

# Show help
show_help() {
    echo -e "${CYAN}${SCRIPT_NAME} - SSH Profile Switcher${NC}"
    print_separator
    echo -e "${GREEN}Usage:${NC}"
    echo "  ${SCRIPT_NAME} sw <profile>      Switch to specified profile"
    echo "  ${SCRIPT_NAME} list             List available profiles"
    echo "  ${SCRIPT_NAME} add <name>       Create empty profile (interactive)"
    echo "  ${SCRIPT_NAME} add <name> -u <login> [-i <keyfile>] [-t <type>] [-s <size>] [-p]  Create profile with options"
    echo "  ${SCRIPT_NAME} bak <name>       Create profile from current ~/.ssh/config"
    echo "  ${SCRIPT_NAME} del <name>       Delete profile"
    echo "  ${SCRIPT_NAME} edit <name>      Edit profile config"
    echo "  ${SCRIPT_NAME} -h|--help        Show this help message"
    echo "  ${SCRIPT_NAME}                  Interactive profile selection"
    print_separator
    echo -e "${YELLOW}Supported key types: rsa, ed25519, ecdsa, dsa${NC}"
    echo -e "${YELLOW}Use -p option to set passphrase for new keys${NC}"
    print_separator
}

# Show profile list
show_profiles() {
    local current=$(get_current_profile)
    local profiles=($(ls -1 "$BASE_DIR" 2>/dev/null | grep -v "^current_profile$" | sort))
    
    echo -e "${GREEN}Available profiles:${NC}"
    print_separator
    
    if [ ${#profiles[@]} -eq 0 ]; then
        echo -e "${YELLOW}No profiles found${NC}"
        echo -e "Create profiles with: ${GREEN}${SCRIPT_NAME} add <name>${NC}"
    else
        for profile in "${profiles[@]}"; do
            if [ "$profile" == "$current" ]; then
                echo -e "  ${GREEN}✓ ${profile} (active)${NC}"
            else
                echo -e "  ${BLUE}•${NC} ${profile}"
            fi
        done
    fi
    print_separator
}

# Interactive profile selection menu
interactive_menu() {
    local profiles=($(ls -1 "$BASE_DIR" 2>/dev/null | grep -v "^current_profile$" | sort))
    local current=$(get_current_profile)
    
    [ ${#profiles[@]} -eq 0 ] && { 
        echo -e "${YELLOW}No profiles found${NC}"
        echo -e "Create profiles with: ${GREEN}${SCRIPT_NAME} add <name>${NC}"
        return
    }

    echo -e "${CYAN}Select SSH profile:${NC}"
    print_separator
    
    for i in "${!profiles[@]}"; do
        [ "${profiles[$i]}" == "$current" ] \
            && printf "%2d) ${GREEN}✓ %s (active)${NC}\n" $((i+1)) "${profiles[$i]}" \
            || printf "%2d) ${BLUE}•${NC} %s\n" $((i+1)) "${profiles[$i]}"
    done
    
    print_separator
    
    while read -p "Enter your choice (1-${#profiles[@]}, q to quit): " choice; do
        [[ "$choice" == "q" ]] && break
        [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#profiles[@]}" ] && {
            switch_profile "${profiles[$((choice-1))]}"
            break
        }
        echo -e "${RED}Invalid selection. Please try again.${NC}"
    done
}

# Create profile (general function)
create_profile() {
    local profile_name="$1" 
    local profile_dir="${BASE_DIR}/${1}"

    is_valid_profile_name "$profile_name" || {
        echo -e "${RED}Error: Invalid profile name. Only letters, numbers, underscores and hyphens are allowed.${NC}"
        exit 1
    }
    
    [ -d "$profile_dir" ] && { echo -e "${RED}Error: Profile '$profile_name' already exists${NC}"; exit 1; }
    mkdir -p "$profile_dir"
    echo "$profile_dir"
}

# Create empty profile (interactive mode)
add_profile_interactive() {
    local profile_dir=$(create_profile "$1")
    local config_file="${profile_dir}/config"
    
    echo -e "${CYAN}Creating new SSH profile: $1${NC}"
    print_separator
    
    read -p "Enter default username for SSH connections: " ssh_user
    
    echo -e "${YELLOW}SSH Key options:${NC}"
    echo "1) Use existing SSH key"
    echo "2) Generate new SSH key"
    echo "3) Don't use SSH key (password authentication)"
    
    while read -p "Select option (1-3): " key_option; do
        case $key_option in
            1)  read -p "Enter path to existing SSH private key: " key_path
                [ -f "$key_path" ] || { echo -e "${RED}Error: Key file not found${NC}"; exit 1; }
                cp "$key_path" "${profile_dir}/id_rsa"
                cp "${key_path}.pub" "${profile_dir}/id_rsa.pub" 2>/dev/null
                fix_file_permissions "${profile_dir}/id_rsa"
                key_path="${profile_dir}/id_rsa"
                break ;;
            2)  # Key type selection
                echo -e "${YELLOW}Select key type:${NC}"
                for i in "${!SUPPORTED_KEY_TYPES[@]}"; do
                    printf "%2d) %s\n" $((i+1)) "${SUPPORTED_KEY_TYPES[$i]}"
                done
                
                while read -p "Enter key type (1-${#SUPPORTED_KEY_TYPES[@]}, default 1): " type_choice; do
                    [ -z "$type_choice" ] && type_choice=1
                    [[ "$type_choice" =~ ^[0-9]+$ ]] && [ "$type_choice" -ge 1 ] && [ "$type_choice" -le "${#SUPPORTED_KEY_TYPES[@]}" ] && break
                    echo -e "${RED}Invalid selection. Please try again.${NC}"
                done
                local key_type="${SUPPORTED_KEY_TYPES[$((type_choice-1))]}"
                
                # Key size prompt (if not ed25519)
                local key_size=""
                if [ "$key_type" != "ed25519" ]; then
                    read -p "Enter key size (default for ${key_type}: ${DEFAULT_KEY_SIZE}): " key_size
                    [ -z "$key_size" ] && key_size="$DEFAULT_KEY_SIZE"
                fi
                
                # Key passphrase prompt
                read -p "Enter passphrase for the key (leave empty for no passphrase): " -s key_passphrase
                echo
                [ -n "$key_passphrase" ] && read -p "Confirm passphrase: " -s key_passphrase_confirm && echo
                [ "$key_passphrase" != "$key_passphrase_confirm" ] && { echo -e "${RED}Error: Passphrases do not match${NC}"; exit 1; }
                
                generate_ssh_key "$profile_dir" "id_${key_type}" "$key_type" "$key_size" "$key_passphrase" || exit 1
                key_path="${profile_dir}/id_${key_type}"
                break ;;
            3)  key_path=""; break ;;
            *)  echo -e "${RED}Invalid option, try again${NC}" ;;
        esac
    done
    
    touch "$config_file"
    echo "Host *" >> "$config_file"
    [ -n "$ssh_user" ] && echo "    User $ssh_user" >> "$config_file"
    [ -n "$key_path" ] && echo "    IdentityFile $key_path" >> "$config_file"
    
    echo "    UserKnownHostsFile ${profile_dir}/known_hosts" >> "$config_file"
    
    touch "${profile_dir}/known_hosts"
    fix_file_permissions "$config_file"
    fix_file_permissions "${profile_dir}/known_hosts"
    
    echo -e "${GREEN}✓ Created profile: $1${NC}"
    echo -e "You can edit it with: ${GREEN}${SCRIPT_NAME} edit $1${NC}"
}

# Create profile with options
add_profile_with_options() {
    local profile_dir=$(create_profile "$1")
    local config_file="${profile_dir}/config"
    local ssh_user="$2"
    local key_path="$3"
    local key_type="$4"
    local key_size="$5"
    local use_passphrase="$6"
    local key_passphrase=""
    
    if [ "$use_passphrase" == "-p" ]; then
        read -p "Enter passphrase for the key: " -s key_passphrase
        echo
        read -p "Confirm passphrase: " -s key_passphrase_confirm
        echo
        [ "$key_passphrase" != "$key_passphrase_confirm" ] && { echo -e "${RED}Error: Passphrases do not match${NC}"; exit 1; }
    fi
    
    touch "$config_file"
    echo "Host *" >> "$config_file"
    [ -n "$ssh_user" ] && echo "    User $ssh_user" >> "$config_file"
    
    if [ -n "$key_path" ]; then
        [ -f "$key_path" ] || { echo -e "${RED}Error: Key file not found${NC}"; exit 1; }
        local key_name=$(basename "$key_path")
        cp "$key_path" "${profile_dir}/${key_name}"
        cp "${key_path}.pub" "${profile_dir}/${key_name}.pub" 2>/dev/null
        fix_file_permissions "${profile_dir}/${key_name}"
        echo "    IdentityFile ${profile_dir}/${key_name}" >> "$config_file"
    else
        generate_ssh_key "$profile_dir" "id_${key_type:-$DEFAULT_KEY_TYPE}" "$key_type" "$key_size" "$key_passphrase" && \
        echo "    IdentityFile ${profile_dir}/id_${key_type:-$DEFAULT_KEY_TYPE}" >> "$config_file"
    fi
    
    echo "    UserKnownHostsFile ${profile_dir}/known_hosts" >> "$config_file"
    
    touch "${profile_dir}/known_hosts"
    fix_file_permissions "$config_file"
    fix_file_permissions "${profile_dir}/known_hosts"
    
    echo -e "${GREEN}✓ Created profile: $1${NC}"
}

# Create profile from current config
backup_current_config() {
    local profile_dir=$(create_profile "$1")
    
    [ -f "$SSH_CONFIG" ] && cp "$SSH_CONFIG" "${profile_dir}/config" || touch "${profile_dir}/config"
    [ -f "$SSH_KNOWN_HOSTS" ] && cp "$SSH_KNOWN_HOSTS" "${profile_dir}/known_hosts" || touch "${profile_dir}/known_hosts"
    
    fix_file_permissions "${profile_dir}/config"
    fix_file_permissions "${profile_dir}/known_hosts"
    
    echo -e "${GREEN}✓ Created profile '$1' from current config${NC}"
}

# Remove profile
remove_profile() {
    local profile_dir="${BASE_DIR}/${1}"
    local current=$(get_current_profile)
    
    [ -d "$profile_dir" ] || { echo -e "${RED}Error: Profile '$1' not found${NC}"; exit 1; }

    # General warning for all profiles
    echo -e "${YELLOW}Warning: You are about to delete profile '$1'${NC}"
    
    # Additional warning for active profile
    [ "$1" == "$current" ] && echo -e "${RED}Warning: This is your current active profile!${NC}"
    
    # Confirmation prompt
    read -p "Are you sure you want to delete this profile? (y/N) " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo -e "${YELLOW}Deletion canceled${NC}"; exit 0; }
    
    # Additional confirmation for active profile
    if [ "$1" == "$current" ]; then
        echo -e "${RED}Final warning: You are deleting your active profile!${NC}"
        read -p "Type 'DELETE' to confirm: " final_confirm
        [[ "$final_confirm" == "DELETE" ]] || { echo -e "${YELLOW}Deletion canceled${NC}"; exit 0; }
        rm -f "$CURRENT_PROFILE_FILE"
    fi
    
    rm -rf "$profile_dir"
    echo -e "${GREEN}✓ Removed profile: $1${NC}"
}

# Edit profile
edit_profile() {
    local config_file="${BASE_DIR}/${1}/config"
    
    [ -f "$config_file" ] || { echo -e "${RED}Error: Profile '$1' not found${NC}"; exit 1; }
    
    ${EDITOR:-vi} "$config_file"
    validate_ssh_config "$config_file" && echo -e "${GREEN}✓ Edited profile: $1${NC}" \
        || echo -e "${YELLOW}Warning: Profile contains errors. Fix them before switching to this profile.${NC}"
}

# Switch profile
switch_profile() {
    local profile_dir="${BASE_DIR}/${1}" 
    local config_file="${profile_dir}/config"
    local current=$(get_current_profile)
    
    [ -d "$profile_dir" ] || { echo -e "${RED}Error: Profile '$1' not found${NC}"; show_profiles; exit 1; }
    
    fix_file_permissions "$config_file"
    [ -f "${profile_dir}/known_hosts" ] && fix_file_permissions "${profile_dir}/known_hosts"
    validate_ssh_config "$config_file" || { echo -e "${RED}Error: Cannot switch to profile '$1' due to config errors${NC}"; exit 1; }
    
    # Save current known_hosts
    [ -n "$current" ] && [ -f "$SSH_KNOWN_HOSTS" ] && cp "$SSH_KNOWN_HOSTS" "${BASE_DIR}/${current}/known_hosts" >/dev/null 2>&1
    
    # Apply new profile
    cp "$config_file" "$SSH_CONFIG" || { echo -e "${RED}Error: Failed to switch profile${NC}"; exit 2; }
    [ -f "${profile_dir}/known_hosts" ] && cp "${profile_dir}/known_hosts" "$SSH_KNOWN_HOSTS"
    
    echo "$1" > "$CURRENT_PROFILE_FILE"
    echo -e "${GREEN}✓ Switched to profile: $1${NC}"
    
    # Add key to ssh-agent if specified in config
    local key_path=$(grep -i '^ *IdentityFile' "$config_file" | awk '{print $2}' | head -n1 | sed -e "s#~#$HOME#")
    if [ -n "$key_path" ] && [ -f "$key_path" ]; then
        add_key_to_ssh_agent "$key_path"
    fi
}

# Parse arguments for add command
parse_add_args() {
    local profile_name="$1"; shift
    local ssh_user=""
    local key_path=""
    local key_type=""
    local key_size=""
    local use_passphrase=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--user) ssh_user="$2"; shift 2 ;;
            -i|--identity) key_path="$2"; shift 2 ;;
            -t|--type) key_type="$2"; shift 2 ;;
            -s|--size) key_size="$2"; shift 2 ;;
            -p|--passphrase) use_passphrase="-p"; shift ;;
            *) echo -e "${RED}Error: Unknown option $1${NC}"; show_help; exit 1 ;;
        esac
    done
    
    [ -z "$ssh_user" ] && add_profile_interactive "$profile_name" || add_profile_with_options "$profile_name" "$ssh_user" "$key_path" "$key_type" "$key_size" "$use_passphrase"
}

# Main command processing logic
case "$1" in 
    sw|switch) [ -z "$2" ] && { echo -e "${RED}Error: Profile name not specified${NC}"; show_help; exit 1; }
               switch_profile "$2" ;;
    add)       [ -z "$2" ] && { echo -e "${RED}Error: Profile name not specified${NC}"; show_help; exit 1; }
               parse_add_args "$2" "${@:3}" ;;
    bak|backup)[ -z "$2" ] && { echo -e "${RED}Error: Profile name not specified${NC}"; show_help; exit 1; }
               backup_current_config "$2" ;;
    del|delete|rm)[ -z "$2" ] && { echo -e "${RED}Error: Profile name not specified${NC}"; show_help; exit 1; }
               remove_profile "$2" ;;
    edit)      [ -z "$2" ] && { echo -e "${RED}Error: Profile name not specified${NC}"; show_help; exit 1; }
               edit_profile "$2" ;;
    list|ls)   show_profiles ;;
    -h|--help|help) show_help ;;
    *)         [ -z "$1" ] && interactive_menu || { echo -e "${RED}Error: Unknown command '$1'${NC}"; show_help; exit 1; } ;;
esac
