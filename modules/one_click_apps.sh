#!/bin/bash
# One-Click Application Deployment Module for Podman Pilot

APPS_CONFIG_DIR="${SCRIPT_DIR}/config/apps"

handle_one_click_apps() {
    while true; do
        local app_files=()
        local options=()
        local i=1

        # Scan for app configuration files
        for app_conf_file in "${APPS_CONFIG_DIR}"/*.conf; do
            if [ -f "$app_conf_file" ]; then
                # Source the conf file to get APP_LANG_KEY
                # Use a subshell to avoid polluting current environment too much if not careful in .conf
                local temp_app_lang_key
                temp_app_lang_key=$(source "$app_conf_file"; echo "$APP_LANG_KEY")

                if [ -n "$temp_app_lang_key" ]; then
                    local app_display_name
                    app_display_name=$(get_string "$temp_app_lang_key")
                    # Store the file path as the tag, and the display name as the item
                    options+=("$(basename "$app_conf_file")" "$app_display_name")
                    app_files+=("$app_conf_file")
                fi
            fi
        done
        
        if [ ${#options[@]} -eq 0 ]; then
            display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_NO_ITEMS_FOUND") (No app configurations in $APPS_CONFIG_DIR)"
            break
        fi

        # Add "Back" option manually to the dialog options array
        # For dialog --menu, tags and items must be paired.
        # If we use numeric tags:
        # for i in "${!app_files[@]}"; do
        #     options+=("$((i+1))" "$(get_string "$(source "${app_files[$i]}"; echo "$APP_LANG_KEY")")")
        # done
        # options+=("0" "$(get_string "LANG_BACK")")

        CHOICE_TAG=$(select_from_list "LANG_APPS_MENU_TITLE" "LANG_APPS_SELECT_TO_DEPLOY" \
                                    "20" "$((${#options[@]}/2 + 1))" "70" "" \
                                    "${options[@]}" "0" "$(get_string "LANG_BACK")")
        exit_status=$?

        if [ $exit_status -ne 0 ] || [ "$CHOICE_TAG" == "0" ]; then # User chose Back or Cancelled
            break 
        fi

        if [ -n "$CHOICE_TAG" ]; then
            local selected_app_conf_file="${APPS_CONFIG_DIR}/${CHOICE_TAG}"
            if [ -f "$selected_app_conf_file" ]; then
                # Source the selected app's config file and call its deploy_app function
                # The deploy_app function is responsible for all user interaction and podman calls
                # Ensure SCRIPT_DIR and utility functions are available to deploy_app
                # (They are exported from podman-pilot.sh and utils.sh)
                source "$selected_app_conf_file" # Load APP_LANG_KEY, APP_IMAGE, deploy_app
                if declare -f deploy_app > /dev/null; then
                    deploy_app # Call the function defined in the .conf file
                else
                    display_error "$(get_string "LANG_ERROR")" "Deployment function 'deploy_app' not found in $selected_app_conf_file."
                fi
            else
                display_error "$(get_string "LANG_ERROR")" "App configuration file $selected_app_conf_file not found."
            fi
        else
            display_error "$(get_string "LANG_INVALID_OPTION")"
        fi
        # Pause to see messages from deploy_app before loop continues
        # echo; read -rp "$(get_string "LANG_PRESS_ANY_KEY")" -n1 key
    done
}

handle_one_click_apps
