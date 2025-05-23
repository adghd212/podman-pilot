#!/bin/bash

# Podman Pilot - Main Script
# Author: adghd212
# Version: 0.1.0

# --- Configuration ---
# Ensure SCRIPT_DIR is set to the absolute path of this script's directory.
# This is crucial for sourcing other files correctly.
export SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="0.1.0"
readonly GITHUB_REPO_OWNER="adghd212"
readonly GITHUB_REPO_NAME="podman-pilot"
readonly GITHUB_MAIN_BRANCH="main" # Or your default branch

# --- Check Bash Version ---
MIN_BASH_VERSION="4.4" # Dialog --default-item with tags might need newer bash for arrays.
# Also for associative arrays if used for language display names.
if [ -z "${BASH_VERSION}" ]; then
    echo "Error: This script must be run with Bash."
    exit 1
fi
# Strip suffix like -release
current_bash_version=$(echo "${BASH_VERSION}" | cut -d'.' -f1,2)
if ! printf '%s\n' "$MIN_BASH_VERSION" "$current_bash_version" | sort -V -C; then
    echo "Error: Bash version ${MIN_BASH_VERSION} or higher is required. You have ${BASH_VERSION}."
    echo "Please upgrade Bash to run Podman Pilot."
    exit 1
fi


# --- Source Utility Functions and Initialize Language ---
# utils.sh contains i18n functions and dialog wrappers.
if [ -f "${SCRIPT_DIR}/lib/utils.sh" ]; then
    source "${SCRIPT_DIR}/lib/utils.sh"
    initialize_language # Determine and load the language
else
    echo "Critical Error: lib/utils.sh not found!"
    echo "Podman Pilot cannot start. Please ensure it is installed correctly."
    exit 1
fi


# --- Dependency Check ---
check_dependencies() {
    local missing_deps=0
    if ! command -v dialog &> /dev/null && ! command -v whiptail &> /dev/null; then
        echo "$(get_string "LANG_ERROR"): $(get_string "LANG_DIALOG_MISSING")" # Add LANG_DIALOG_MISSING to lang files
        missing_deps=1
    fi
    if ! command -v podman &> /dev/null; then
        # This is a soft warning, as the script can install podman
        echo "$(get_string "LANG_WARNING"): $(get_string "LANG_PODMAN_NOT_INSTALLED")"
    fi
    if ! command -v curl &> /dev/null; then
        echo "$(get_string "LANG_ERROR"): $(get_string "LANG_CURL_MISSING")" # Add LANG_CURL_MISSING
        missing_deps=1
    fi
     if ! command -v jq &> /dev/null; then
        echo "$(get_string "LANG_WARNING"): $(get_string "LANG_JQ_NOT_FOUND_WARN")" # Add LANG_JQ_NOT_FOUND_WARN
        # JQ is not strictly critical for startup, modules will check again.
    fi

    if [ $missing_deps -ne 0 ]; then
        echo "$(get_string "LANG_PLEASE_INSTALL_DEPS")" # Add LANG_PLEASE_INSTALL_DEPS
        exit 1
    fi
}
# Add these to lang files:
# LANG_DIALOG_MISSING: "dialog (or whiptail) is not installed. Please install it (e.g., sudo apt install dialog)."
# LANG_CURL_MISSING: "curl is not installed. It's required for updates. Please install it (e.g., sudo apt install curl)."
# LANG_JQ_NOT_FOUND_WARN: "jq is not installed. Some inspection features might not work optimally."
# LANG_PLEASE_INSTALL_DEPS: "Please install the missing critical dependencies and try again."


# --- GitHub Updater ---
update_script_curl() {
    display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_UPDATE_FETCHING")"
    
    local manifest_url="https://raw.githubusercontent.com/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}/${GITHUB_MAIN_BRANCH}/FILE_MANIFEST.txt"
    local temp_manifest
    temp_manifest=$(mktemp)

    if ! curl -sSL "$manifest_url" -o "$temp_manifest"; then
        display_error "$(get_string "LANG_UPDATE_MANIFEST_FAILED")"
        rm "$temp_manifest"
        return 1
    fi

    if [ ! -s "$temp_manifest" ]; then
        display_error "$(get_string "LANG_UPDATE_MANIFEST_FAILED") (empty manifest)"
        rm "$temp_manifest"
        return 1
    fi
    
    local update_errors=0
    # Read manifest line by line: "destination_path file_type(f/d)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines or comments
        [[ -z "$line" || "$line" == \#* ]] && continue

        local dest_path file_type
        # Assuming format "path type" e.g. "modules/manage_pods.sh f" or "config/apps d"
        dest_path=$(echo "$line" | awk '{print $1}')
        file_type=$(echo "$line" | awk '{print $2}')

        local local_full_path="${SCRIPT_DIR}/${dest_path}"
        local remote_raw_url="https://raw.githubusercontent.com/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}/${GITHUB_MAIN_BRANCH}/${dest_path}"

        if [[ "$file_type" == "d" ]]; then # Directory
            if [ ! -d "$local_full_path" ]; then
                mkdir -p "$local_full_path"
                if [ $? -ne 0 ]; then
                    display_error "$(get_string "LANG_ERROR")" "Failed to create directory $local_full_path"
                    update_errors=$((update_errors + 1))
                fi
            fi
        elif [[ "$file_type" == "f" ]]; then # File
             # Ensure parent directory exists
            local parent_dir
            parent_dir=$(dirname "$local_full_path")
            if [ ! -d "$parent_dir" ]; then
                mkdir -p "$parent_dir"
            fi

            echo "$(get_string "LANG_PLEASE_WAIT") Downloading $dest_path..."
            if curl -sSL "$remote_raw_url" -o "${local_full_path}.tmp"; then
                if [ -s "${local_full_path}.tmp" ]; then
                    mv "${local_full_path}.tmp" "${local_full_path}"
                    # Ensure executable if it's a script in modules/ or the main script
                    if [[ "$dest_path" == *.sh || "$dest_path" == "podman-pilot.sh" ]]; then
                        chmod +x "${local_full_path}"
                    fi
                else
                    display_error "$(get_string "LANG_UPDATE_FILE_EMPTY" "$dest_path")"
                    rm -f "${local_full_path}.tmp"
                    update_errors=$((update_errors + 1))
                fi
            else
                display_error "$(get_string "LANG_UPDATE_FAILED" "$dest_path")"
                rm -f "${local_full_path}.tmp"
                update_errors=$((update_errors + 1))
            fi
        fi
    done < "$temp_manifest"
    rm "$temp_manifest"

    if [ $update_errors -eq 0 ]; then
        display_message "$(get_string "LANG_SUCCESS")" "$(get_string "LANG_UPDATE_COMPLETE_RESTART")"
    else
        display_error "$(get_string "LANG_ERROR")" "$(get_string "LANG_UPDATE_FAILED_MULTIPLE_FILES")" # Add this key
    fi
    return $update_errors
}
# Add to lang files: LANG_UPDATE_FAILED_MULTIPLE_FILES: "Update process completed with one or more errors."


update_script_git() {
    if ! command -v git &> /dev/null; then
        display_error "Git is not installed. Cannot update using git." # TODO: i18n this
        return 1
    fi
    # Check if current SCRIPT_DIR is a git repo
    if [ ! -d "${SCRIPT_DIR}/.git" ]; then
        display_error "Not a git repository. Cannot update using git." # TODO: i18n this
        # Offer to switch to curl method or re-clone? For now, just error.
        return 1
    fi

    display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_UPDATE_METHOD_GIT")"
    
    # Stash local changes? Or ask user? For now, assume they manage their changes.
    # A safer way: git fetch && git reset --hard origin/main (but this discards local changes)
    # Simpler: git pull
    local current_branch
    current_branch=$(cd "$SCRIPT_DIR" && git rev-parse --abbrev-ref HEAD)
    
    # Fetch remote changes first
    if ! (cd "$SCRIPT_DIR" && git fetch origin "$current_branch"); then
         display_error "$(get_string "LANG_UPDATE_GIT_PULL_FAILED") (fetch failed)"
         return 1
    fi

    # Check if local is behind remote
    local local_hash remote_hash
    local_hash=$(cd "$SCRIPT_DIR" && git rev-parse HEAD)
    remote_hash=$(cd "$SCRIPT_DIR" && git rev-parse "origin/${current_branch}")

    if [ "$local_hash" == "$remote_hash" ]; then
        display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_UPDATE_GIT_UP_TO_DATE")"
        return 0
    fi

    # Attempt to pull. This might fail if there are local uncommitted changes that conflict.
    if (cd "$SCRIPT_DIR" && git pull origin "$current_branch"); then
        display_message "$(get_string "LANG_SUCCESS")" "$(get_string "LANG_UPDATE_COMPLETE_RESTART")"
    else
        display_error "$(get_string "LANG_UPDATE_GIT_PULL_FAILED")"
        display_message "$(get_string "LANG_INFO")" "You might need to resolve conflicts manually in $SCRIPT_DIR or stash your changes." # TODO: i18n
        return 1
    fi
    return 0
}

update_script_main() {
    if confirm_dialog "$(get_string "LANG_CONFIRM_ACTION")" "$(get_string "LANG_UPDATE_CONFIRM")"; then
        # Prefer git if available and in a git repo
        if command -v git &> /dev/null && [ -d "${SCRIPT_DIR}/.git" ]; then
            update_script_git
        else
            # Fallback to curl method if a FILE_MANIFEST.txt is maintained in the repo
            # Ensure FILE_MANIFEST.txt exists in the repo root listing all files and their types (f/d)
            # Example FILE_MANIFEST.txt:
            # podman-pilot.sh f
            # lib/utils.sh f
            # modules/ d
            # modules/install_podman.sh f
            # ... etc.
            update_script_curl
        fi
    fi
}


# --- Language Switching Function ---
switch_language() {
    # Define display names for languages here or load from language files themselves if they define e.g. LANG_SELF_NAME
    declare -A lang_display_names=(
        ["en"]="$(source "${LANG_DIR}/en.sh"; get_string "LANG_SELF_NAME_EN")" # Default if LANG_SELF_NAME_EN not in en.sh
        ["zh_CN"]="$(source "${LANG_DIR}/zh_CN.sh"; get_string "LANG_SELF_NAME_ZH_CN")"
        # Add more languages here: ["fr"]="Français"
    )
    # Fallback for display names if not found in array
    lang_display_names["en"]=${lang_display_names["en"]:-"English"}
    lang_display_names["zh_CN"]=${lang_display_names["zh_CN"]:-"简体中文"}


    local lang_options=()
    local lang_files_found=() # Store actual lang codes found
    
    for lang_file in "${LANG_DIR}"/*.sh; do
        if [ -f "$lang_file" ]; then
            local lang_code
            lang_code=$(basename "$lang_file" .sh) # e.g., en, zh_CN
            lang_files_found+=("$lang_code")
        fi
    done

    if [ ${#lang_files_found[@]} -eq 0 ]; then
        display_error "$(get_string "LANG_NO_LANG_FILES_FOUND")"
        return
    fi

    # Build dialog menu options: tag item tag item ...
    for code in "${lang_files_found[@]}"; do
        local display_name="${lang_display_names[$code]}"
        if [ -z "$display_name" ]; then # Fallback if display name not defined
            display_name="$code"
        fi
        lang_options+=("$code" "$display_name")
    done

    # Use select_from_list helper
    local CHOSEN_LANG_CODE
    CHOSEN_LANG_CODE=$(select_from_list "LANG_SWITCH_LANGUAGE_PROMPT" "LANG_SELECT_AN_OPTION" \
                                   "15" "$((${#lang_options[@]}/2))" "60" "$CURRENT_LANG" \
                                   "${lang_options[@]}")
    exit_status=$?

    if [ $exit_status -eq 0 ] && [ -n "$CHOSEN_LANG_CODE" ]; then
        if [ "$CHOSEN_LANG_CODE" != "$CURRENT_LANG" ]; then
            if load_language_file "$CHOSEN_LANG_CODE"; then # This updates CURRENT_LANG and saves preference
                display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_SWITCH_LANGUAGE_RESTART_NOTE")"
                # The main loop will redraw the menu with new language strings
            else
                # This case should ideally not happen if lang_files_found was populated correctly
                display_error "$(get_string "LANG_ERROR")" "Failed to load language $CHOSEN_LANG_CODE."
            fi
        fi
    fi
}

# --- Main Menu ---
main_menu() {
    check_dependencies # Check critical deps on startup

    while true; do
        # Dynamically get menu item strings for the current language
        local item1 item2 item3 item4 item5 item6 item7 item8 item0
        item1=$(get_string "LANG_MENU_INSTALL_PODMAN")
        item2=$(get_string "LANG_MENU_MANAGE_REGISTRIES")
        item3=$(get_string "LANG_MENU_MANAGE_PODS")
        item4=$(get_string "LANG_MENU_MANAGE_IMAGES")
        item5=$(get_string "LANG_MENU_MANAGE_CONTAINERS")
        item6=$(get_string "LANG_MENU_ONE_CLICK_APPS")
        item7=$(get_string "LANG_MENU_UPDATE_SCRIPT")
        item8=$(get_string "LANG_MENU_SWITCH_LANGUAGE")
        item0=$(get_string "LANG_EXIT")

        local menu_height=$(( ${#item1} > 0 ? 10 : 0 )) # Basic dynamic height attempt
        menu_height=$(( menu_height + 8 )) # Base height for options

        local CHOICE
        CHOICE=$(dialog --clear --backtitle "$(get_string "LANG_MAIN_MENU_BACKTITLE") (v${SCRIPT_VERSION})" \
                        --title "$(get_string "LANG_MAIN_MENU_TITLE")" \
                        --ok-label "$(get_string "LANG_OK")" \
                        --cancel-label "$(get_string "LANG_EXIT")" \
                        --menu "$(get_string "LANG_SELECT_AN_OPTION")" "$menu_height" 75 10 \
                        "1" "$item1" \
                        "2" "$item2" \
                        "3" "$item3" \
                        "4" "$item4" \
                        "5" "$item5" \
                        "6" "$item6" \
                        "7" "$item7" \
                        "8" "$item8" \
                        "0" "$item0" \
                        2>&1 >/dev/tty)
        
        local exit_status=$?
        clear # Clear dialog from screen

        if [ $exit_status -ne 0 ]; then # If Cancel or Esc pressed on main menu (value is 1 or 255)
            if confirm_dialog "$(get_string "LANG_EXIT")" "$(get_string "LANG_ARE_YOU_SURE")"; then
                 echo "$(get_string "LANG_EXITING_MSG")"
                 exit 0
            else
                continue # Go back to main menu
            fi
        fi
        
        # Export functions that modules might need if they are not already.
        # utils.sh already exports get_string, display_message etc.

        case $CHOICE in
            1) source "${SCRIPT_DIR}/modules/install_podman.sh" ;;
            2) source "${SCRIPT_DIR}/modules/manage_registries.sh" ;;
            3) source "${SCRIPT_DIR}/modules/manage_pods.sh" ;;
            4) source "${SCRIPT_DIR}/modules/manage_images.sh" ;;
            5) source "${SCRIPT_DIR}/modules/manage_containers.sh" ;;
            6) source "${SCRIPT_DIR}/modules/one_click_apps.sh" ;;
            7) update_script_main ;;
            8) switch_language ;;
            0) 
               if confirm_dialog "$(get_string "LANG_EXIT")" "$(get_string "LANG_ARE_YOU_SURE")"; then
                 echo "$(get_string "LANG_EXITING_MSG")"
                 exit 0
               fi
               ;;
            *) 
               # This case should ideally not be reached if dialog is used correctly
               display_error "$(get_string "LANG_INVALID_OPTION")" 
               ;;
        esac
        # Add a small pause or "press key to continue" if modules don't end with a dialog
        # echo; read -rp "$(get_string "LANG_PRESS_ANY_KEY")" -n1 key
    done
}

# --- Script Entry Point ---
main_menu
