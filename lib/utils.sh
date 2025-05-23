#!/bin/bash

# Podman Pilot Utility Functions
# This script assumes it's sourced by other scripts located in the main project directory or modules directory.
# SCRIPT_DIR should be defined by the calling script, pointing to the root of the podman-pilot project.
# Example in calling script: SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" (if utils.sh is in a subdir of where it's called)
# Or: SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" (if utils.sh is in lib/ and called from module)

# Ensure SCRIPT_DIR is available, if not, try to determine it.
# This is tricky because utils.sh can be sourced from different depths.
# The main podman-pilot.sh should export SCRIPT_DIR.
if [ -z "$SCRIPT_DIR" ]; then
    # Attempt to find the root directory assuming a known structure like /lib/ or /modules/
    _UTILS_PATH_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "$_UTILS_PATH_ABS" == */lib ]]; then
        SCRIPT_DIR="$(cd "$_UTILS_PATH_ABS/.." && pwd)"
    elif [[ "$_UTILS_PATH_ABS" == */modules ]]; then # Should not happen as modules source utils.sh
        SCRIPT_DIR="$(cd "$_UTILS_PATH_ABS/.." && pwd)"
    else # Assume utils.sh is at the root or SCRIPT_DIR is set by caller
        SCRIPT_DIR="$_UTILS_PATH_ABS"
    fi
    # Fallback if SCRIPT_DIR is still not determined correctly
    if [ ! -f "${SCRIPT_DIR}/podman-pilot.sh" ]; then
        echo "Error: SCRIPT_DIR not correctly set or podman-pilot.sh not found. utils.sh cannot determine project root."
        echo "SCRIPT_DIR was determined as: ${SCRIPT_DIR}"
        # exit 1 # Exiting might be too aggressive if only some utils are used without full context
    fi
fi


# --- I18N Configuration ---
CURRENT_LANG="en" # Default language
LANG_DIR="${SCRIPT_DIR}/lang"
PERSISTED_LANG_FILE="${LANG_DIR}/.current_lang" # File to store user's language preference

# Function to load language file
# It sources the variables from the language file into the current shell.
load_language_file() {
    local lang_to_load="$1"
    local lang_file_path="${LANG_DIR}/${lang_to_load}.sh"

    if [ -f "$lang_file_path" ]; then
        # Unset previous language variables to avoid conflicts if some keys are missing in new lang file
        # This is a simple approach; a more robust one would be to manage a specific namespace.
        # For now, we rely on all lang files being complete.
        # Alternatively, only load if CURRENT_LANG changes significantly.
        source "$lang_file_path"
        CURRENT_LANG="$lang_to_load"
        if [ -w "$(dirname "$PERSISTED_LANG_FILE")" ]; then # Check if directory is writable
            echo "$CURRENT_LANG" > "$PERSISTED_LANG_FILE"
        else
            # Non-critical error, user preference won't be saved.
            # This might happen if lang dir is not writable by the user.
            true # echo "Warning: Cannot save language preference to $PERSISTED_LANG_FILE."
        fi
        return 0
    else
        return 1 # File not found
    fi
}

# Initialize language settings. Call this once at the beginning of the main script.
initialize_language() {
    local preferred_lang=""
    # 1. Check persisted preference
    if [ -f "$PERSISTED_LANG_FILE" ]; then
        preferred_lang=$(cat "$PERSISTED_LANG_FILE")
    fi

    # 2. If no persisted or persisted is invalid, check system $LANG
    if [ -z "$preferred_lang" ] || ! [ -f "${LANG_DIR}/${preferred_lang}.sh" ]; then
        if [ -n "$LANG" ]; then
            local sys_lang_base="${LANG%%.*}" # e.g., zh_CN from zh_CN.UTF-8
            if [ -f "${LANG_DIR}/${sys_lang_base}.sh" ]; then
                preferred_lang="$sys_lang_base"
            else
                # Try base language if regional is not found (e.g., zh from zh_CN)
                local sys_lang_main="${sys_lang_base%_*}"
                if [ -f "${LANG_DIR}/${sys_lang_main}.sh" ]; then
                    preferred_lang="$sys_lang_main"
                fi
            fi
        fi
    fi

    # 3. Load preferred language or fallback to 'en'
    if [ -n "$preferred_lang" ] && load_language_file "$preferred_lang"; then
        : # Language loaded
    elif load_language_file "en"; then # Try to load English as a fallback
        : # English loaded
    else
        echo "FATAL ERROR: Default English language file (en.sh) not found in ${LANG_DIR}."
        echo "Please ensure Podman Pilot is installed correctly."
        exit 1
    fi
}

# Function to get translated string
# Usage: local my_string; my_string=$(get_string "LANG_SOME_KEY")
#        local formatted_string; formatted_string=$(get_string "LANG_SOME_FORMAT_KEY" "argument1" "argument2")
get_string() {
    local key="$1"
    shift # Remove the key, remaining are arguments for printf
    local value # Declare local variable
    
    # Indirect variable expansion
    # Check if the variable is set, otherwise it might expand to empty if key is not LANG_ prefixed
    if declare -p "$key" &>/dev/null; then
        value="${!key}"
    else
        # Fallback if key is completely undefined
        value="$key (KEY_UNDEFINED)"
    fi


    # If value is empty or still the key itself (meaning not found in current lang)
    if [ -z "$value" ] || [ "$value" == "$key" ]; then
        # Simple fallback: return the key with a marker
        # A more complex fallback could try to load from 'en.sh' if not already 'en'
        value="$key (missing translation)"
    fi

    if [ $# -gt 0 ]; then # If there are additional arguments, treat value as a format string
        # shellcheck disable=SC2059 # We intend for value to be a format string for printf
        printf "$value" "$@"
    else
        echo "$value"
    fi
}
export -f get_string # Make available to sourced scripts


# --- Dialog UI Helper Functions ---

# display_message "Title Key" "Message Key" ["arg1" "arg2" ...]
display_message() {
    local title_key="$1"
    local msg_key="$2"
    shift 2
    local title_str msg_str
    title_str=$(get_string "$title_key")
    msg_str=$(get_string "$msg_key" "$@")
    dialog --backtitle "$(get_string "LANG_MAIN_MENU_BACKTITLE")" \
           --title "$title_str" \
           --ok-label "$(get_string "LANG_OK")" \
           --msgbox "$msg_str" 10 70
    clear
}
export -f display_message

# display_error "Message Key" ["arg1" "arg2" ...]
display_error() {
    local msg_key="$1"
    shift
    local error_title_str msg_str
    error_title_str=$(get_string "LANG_ERROR")
    msg_str=$(get_string "$msg_key" "$@")
    dialog --backtitle "$(get_string "LANG_MAIN_MENU_BACKTITLE")" \
           --title "$error_title_str" \
           --ok-label "$(get_string "LANG_OK")" \
           --msgbox "$msg_str" 10 70
    clear
}
export -f display_error

# value=$(get_input "Prompt Key" "Default Value" ["arg_for_prompt"])
# Returns the input value, or empty string if Cancel/Esc. Exit status also reflects this.
get_input() {
    local prompt_key="$1"
    local default_value="$2"
    shift 2
    local prompt_str info_title_str
    
