#!/bin/bash
# Podman Installation Management Module for Podman Pilot

# This script is sourced by podman-pilot.sh, so it has access to SCRIPT_DIR, get_string, etc.

handle_podman_installation() {
    while true; do
        local cmd_podman_exists=false
        command -v podman &> /dev/null && cmd_podman_exists=true

        local options=(
            "1" "$(get_string "LANG_PODMAN_INSTALL")"
            "2" "$(get_string "LANG_PODMAN_UNINSTALL")"
            "3" "$(get_string "LANG_PODMAN_STATUS")"
            "0" "$(get_string "LANG_BACK")"
        )
        
        CHOICE=$(select_from_list "LANG_PODMAN_MENU_TITLE" "LANG_SELECT_AN_OPTION" "15" "4" "60" "" "${options[@]}")
        exit_status=$?

        if [ $exit_status -ne 0 ]; then # User pressed Cancel or Esc
            break 
        fi

        case $CHOICE in
            1) # Install Podman
                if $cmd_podman_exists; then
                    display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_PODMAN_ALREADY_INSTALLED")"
                else
                    if confirm_dialog "$(get_string "LANG_CONFIRM_ACTION")" "$(get_string "LANG_PODMAN_INSTALL_CONFIRM")"; then
                        display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_PODMAN_INSTALLING")"
                        if sudo apt update && sudo apt install -y podman; then
                            display_message "$(get_string "LANG_SUCCESS")" "$(get_string "LANG_PODMAN_INSTALL_SUCCESS")"
                            command -v podman &> /dev/null && cmd_podman_exists=true # Update status
                        else
                            display_error "$(get_string "LANG_PODMAN_INSTALL_FAILED")"
                        fi
                    fi
                fi
                ;;
            2) # Uninstall Podman
                if ! $cmd_podman_exists; then
                    display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_PODMAN_NOT_INSTALLED")"
                else
                    if confirm_dialog "$(get_string "LANG_CONFIRM_ACTION")" "$(get_string "LANG_PODMAN_UNINSTALL_CONFIRM")"; then
                        local purge_podman_data=false
                        if confirm_dialog "$(get_string "LANG_CONFIRM_ACTION")" "$(get_string "LANG_PODMAN_UNINSTALL_PURGE_CONFIRM")"; then
                            purge_podman_data=true
                        fi
                        
                        display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_PODMAN_UNINSTALLING")"
                        local uninstall_cmd="sudo apt remove -y podman"
                        if $purge_podman_data; then
                            uninstall_cmd="sudo apt purge -y podman && sudo rm -rf ~/.local/share/containers/storage ~/.config/containers"
                            # Warn about manual cleanup for other users if system-wide data was used
                        fi

                        # Execute the command string
                        if eval "$uninstall_cmd"; then
                            display_message "$(get_string "LANG_SUCCESS")" "$(get_string "LANG_PODMAN_UNINSTALL_SUCCESS")"
                            command -v podman &> /dev/null || cmd_podman_exists=false # Update status
                        else
                            display_error "$(get_string "LANG_PODMAN_UNINSTALL_FAILED")"
                        fi
                    fi
                fi
                ;;
            3) # Check Podman Status
                if $cmd_podman_exists; then
                    local version_info status_info
                    version_info=$(podman version 2>&1)
                    status_info=$(systemctl status podman.socket 2>&1 || systemctl status podman 2>&1 || echo "$(get_string "LANG_PODMAN_SERVICE_STATUS_UNKNOWN")")

                    local full_status_message
                    full_status_message="$(get_string "LANG_PODMAN_VERSION_INFO")\n$version_info\n\n$(get_string "LANG_PODMAN_SERVICE_STATUS")\n$status_info"
                    
                    echo -e "$full_status_message" | dialog --backtitle "$(get_string "LANG_MAIN_MENU_BACKTITLE")" \
                                                            --title "$(get_string "LANG_PODMAN_STATUS")" \
                                                            --ok-label "$(get_string "LANG_OK")" \
                                                            --programbox 20 70
                    clear
                else
                    display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_PODMAN_NOT_INSTALLED")"
                    display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_PODMAN_CHECK_MANUAL")"
                fi
                ;;
            0) # Back
                break
                ;;
            *)
                display_error "$(get_string "LANG_INVALID_OPTION")"
                ;;
        esac
        # Add a small pause or press key to continue if needed after an action.
        # For now, dialogs serve this purpose.
    done
}

# This makes the function callable when sourced by podman-pilot.sh
handle_podman_installation
