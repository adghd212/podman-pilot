# lib/utils.sh (或 podman-pilot.sh 顶部)

# --- I18N Functions ---
CURRENT_LANG="en" # Default language
LANG_DIR="$(dirname "$0")/../lang" # Assuming utils.sh is in lib/
if [[ "$(basename "$0")" == "podman-pilot.sh" ]]; then
    LANG_DIR="./lang" # If these functions are directly in podman-pilot.sh
fi

# Function to load language file
load_language() {
    local lang_file="$1"
    if [ -f "$lang_file" ]; then
        source "$lang_file"
        # Store chosen language preference, e.g., in a temp file or config
        echo "$CURRENT_LANG" > "${LANG_DIR}/.current_lang"
    else
        echo "Warning: Language file $lang_file not found. Falling back to English."
        source "${LANG_DIR}/en.sh" # Fallback
    fi
}

# Attempt to load preferred language on script start
if [ -f "${LANG_DIR}/.current_lang" ]; then
    PREFERRED_LANG=$(cat "${LANG_DIR}/.current_lang")
    if [ -n "$PREFERRED_LANG" ] && [ -f "${LANG_DIR}/${PREFERRED_LANG}.sh" ]; then
        CURRENT_LANG="$PREFERRED_LANG"
    fi
elif [ -n "$LANG" ]; then # LANG environment variable (e.g., zh_CN.UTF-8)
    LOCALE_LANG_CODE="${LANG%%.*}" # Get zh_CN from zh_CN.UTF-8
    if [ -f "${LANG_DIR}/${LOCALE_LANG_CODE}.sh" ]; then
        CURRENT_LANG="$LOCALE_LANG_CODE"
    elif [ -f "${LANG_DIR}/${LOCALE_LANG_CODE%_**}.sh" ]; then # Try just 'zh' from 'zh_CN'
        CURRENT_LANG="${LOCALE_LANG_CODE%_**}"
    fi
fi
load_language "${LANG_DIR}/${CURRENT_LANG}.sh"


# Function to get translated string
# Usage: local my_string=$(get_string "LANG_SOME_KEY")
#        local formatted_string=$(get_string "LANG_SOME_FORMAT_KEY" "argument1" "argument2")
get_string() {
    local key="$1"
    shift # Remove the key, remaining are arguments for printf
    local value="${!key}" # Indirect expansion

    if [ -z "$value" ]; then
        # Fallback if key not found in current lang, try English
        if [ "$CURRENT_LANG" != "en" ]; then
            local en_value
            # Temporarily load english to get the string, not ideal but works for simple cases
            # A better approach might be to have a global array of English strings always loaded
            # For now, we'll just show the key or a placeholder
            # To implement proper fallback: grep from en.sh
            # en_value=$(grep "^${key}=" "${LANG_DIR}/en.sh" | cut -d'=' -f2- | sed 's/"//g')
            # if [ -n "$en_value" ]; then value="$en_value"; else value="$key (missing)"; fi
             value="$key (missing)"
        else
            value="$key (missing)"
        fi
    fi

    if [ $# -gt 0 ]; then # If there are additional arguments, treat value as a format string
        # shellcheck disable=SC2059 # We intend for value to be a format string
        printf "$value" "$@"
    else
        echo "$value"
    fi
}

# Update existing dialog functions to use get_string
display_message() {
    # Title Key, Message Key, optional args for message
    local title_key="$1"
    local msg_key="$2"
    shift 2
    dialog --title "$(get_string "$title_key")" --ok-label "$(get_string "LANG_OK")" --msgbox "$(get_string "$msg_key" "$@")" 8 70
}

display_error() {
    # Message Key, optional args for message
    local msg_key="$1"
    shift
    dialog --title "$(get_string "LANG_ERROR")" --ok-label "$(get_string "LANG_OK")" --msgbox "$(get_string "$msg_key" "$@")" 8 70
}

get_input() {
    # Prompt Key, Default Value (literal), optional args for prompt
    local prompt_key="$1"
    local default_value="$2"
    shift 2
    dialog --title "$(get_string "$LANG_INFO")" \
           --ok-label "$(get_string "LANG_OK")" --cancel-label "$(get_string "LANG_CANCEL")" \
           --inputbox "$(get_string "$prompt_key" "$@")" 8 60 "$default_value" 2>&1 >/dev/tty
}

# Yes/No dialog
# Usage: if confirm_dialog "LANG_CONFIRM_DELETE_TITLE" "LANG_CONFIRM_DELETE_MSG"; then ...
confirm_dialog() {
    local title_key="$1"
    local msg_key="$2"
    shift 2
    dialog --title "$(get_string "$title_key")" \
           --yes-label "$(get_string "LANG_YES")" --no-label "$(get_string "LANG_NO")" \
           --yesno "$(get_string "$msg_key" "$@")" 8 70
    return $? # Returns 0 for Yes, 1 for No, 255 for Esc
}
