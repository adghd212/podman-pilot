#!/bin/bash
# Manage Pods Module for Podman Pilot

list_pods_for_selection() {
    local pod_info selected_pod_id
    # Format: ID Name Status Created InfraID NumContainers
    # We need ID and Name for selection
    # Use --format "{{.ID}} {{.Name}}"
    mapfile -t pod_lines < <(podman pod ps --format "{{.ID}}\t{{.Name}}\t{{.Status}}\t{{.Containers}}" 2>/dev/null)
    
    if [ ${#pod_lines[@]} -eq 0 ]; then
        display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_PODS_NO_PODS_FOUND")"
        return 1
    fi

    local options=()
    for line in "${pod_lines[@]}"; do
        local pod_id pod_name pod_status num_containers
        # Read tab-separated values
        IFS=$'\t' read -r pod_id pod_name pod_status num_containers <<< "$line"
        options+=("$pod_id" "Name: $pod_name (Status: $pod_status, Containers: $num_containers)")
    done
    
    selected_pod_id=$(select_from_list "$(get_string "$1")" \
                                     "$(get_string "LANG_PODS_SELECT_POD")" \
                                     "20" "$((${#options[@]}/2))" "70" "" \
                                     "${options[@]}")
    local exit_status=$?
    if [ $exit_status -eq 0 ] && [ -n "$selected_pod_id" ]; then
        echo "$selected_pod_id"
        return 0
    else
        return 1 # Cancelled or no selection
    fi
}


handle_manage_pods() {
    while true; do
        local options=(
            "1" "$(get_string "LANG_PODS_LIST")"
            "2" "$(get_string "LANG_PODS_CREATE")"
            "3" "$(get_string "LANG_PODS_START")"
            "4" "$(get_string "LANG_PODS_STOP")"
            "5" "$(get_string "LANG_PODS_RESTART")"
            "6" "$(get_string "LANG_PODS_KILL")"
            "7" "$(get_string "LANG_PODS_PAUSE")"
            "8" "$(get_string "LANG_PODS_UNPAUSE")"
            "9" "$(get_string "LANG_PODS_INSPECT")"
            "10" "$(get_string "LANG_PODS_DELETE")"
            "0" "$(get_string "LANG_BACK")"
        )

        CHOICE=$(select_from_list "LANG_PODS_MENU_TITLE" "LANG_SELECT_AN_OPTION" "20" "11" "60" "" "${options[@]}")
        exit_status=$?
        if [ $exit_status -ne 0 ]; then break; fi

        case $CHOICE in
            1) # List Pods
                show_output_scrollbox "$(get_string "LANG_PODS_LIST")" podman pod ps -a --format "table {{.ID}}\\t{{.Name}}\\t{{.Status}}\\t{{.Created}}\\t{{.Containers}}"
                ;;
            2) # Create Pod
                local pod_name port_mappings share_opts
                pod_name=$(get_input "LANG_PODS_ENTER_NAME" "")
                if [ -z "$pod_name" ]; then display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_ACTION_CANCELLED")"; continue; fi
                
                port_mappings=$(get_input "LANG_PODS_ENTER_PORTS" "") # e.g., 8080:80,443:443
                
                # share_opts=$(get_input "LANG_PODS_SHARE_NET_PID_IPC" "") # e.g., net,pid or host

                local cmd_args=()
                [ -n "$port_mappings" ] && IFS=',' read -ra ports <<< "$port_mappings" && for p in "${ports[@]}"; do cmd_args+=("-p" "$p"); done
                # [ -n "$share_opts" ] && cmd_args+=("--share" "$share_opts")
                
                display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_PODS_CREATING" "$pod_name")"
                if podman pod create --name "$pod_name" "${cmd_args[@]}"; then
                    display_message "$(get_string "LANG_SUCCESS")" "$(get_string "LANG_PODS_CREATED_SUCCESS" "$pod_name")"
                else
                    display_error "$(get_string "LANG_PODS_CREATE_FAILED" "$pod_name")"
                fi
                ;;
            3|4|5|6|7|8|9|10) # Operations requiring pod selection
                local action_title action_lang_key pod_id operation_cmd_key success_key fail_key podman_action
                
                case $CHOICE in
                    3) action_title="LANG_PODS_START"; podman_action="start"; success_key="LANG_PODS_STARTED_SUCCESS"; fail_key="LANG_PODS_START_FAILED"; operation_cmd_key="LANG_PODS_STARTING" ;;
                    4) action_title="LANG_PODS_STOP"; podman_action="stop"; success_key="LANG_PODS_STOPPED_SUCCESS"; fail_key="LANG_PODS_STOP_FAILED"; operation_cmd_key="LANG_PODS_STOPPING" ;;
                    5) action_title="LANG_PODS_RESTART"; podman_action="restart"; success_key="LANG_OPERATION_SUCCESSFUL"; fail_key="LANG_OPERATION_FAILED"; operation_cmd_key="LANG_PODS_RESTARTING" ;;
                    6) action_title="LANG_PODS_KILL"; podman_action="kill"; success_key="LANG_OPERATION_SUCCESSFUL"; fail_key="LANG_OPERATION_FAILED"; operation_cmd_key="LANG_PODS_KILLING" ;;
                    7) action_title="LANG_PODS_PAUSE"; podman_action="pause"; success_key="LANG_OPERATION_SUCCESSFUL"; fail_key="LANG_OPERATION_FAILED"; operation_cmd_key="LANG_PODS_PAUSING" ;;
                    8) action_title="LANG_PODS_UNPAUSE"; podman_action="unpause"; success_key="LANG_OPERATION_SUCCESSFUL"; fail_key="LANG_OPERATION_FAILED"; operation_cmd_key="LANG_PODS_UNPAUSING" ;;
                    9) action_title="LANG_PODS_INSPECT"; podman_action="inspect"; operation_cmd_key="LANG_PODS_INSPECTING" ;;
                    10) action_title="LANG_PODS_DELETE"; podman_action="rm"; success_key="LANG_PODS_DELETED_SUCCESS"; fail_key="LANG_PODS_DELETE_FAILED"; operation_cmd_key="LANG_PODS_DELETING" ;;
                esac

                pod_id=$(list_pods_for_selection "$action_title")
                if [ -z "$pod_id" ]; then continue; fi # No pod selected or no pods found
                
                local pod_name_for_msg
                pod_name_for_msg=$(podman pod inspect "$pod_id" --format "{{.Name}}" 2>/dev/null || echo "$pod_id")


                if [ "$podman_action" == "inspect" ]; then
                     if ! check_command "jq" "LANG_JQ_REQUIRED"; then continue; fi
                    show_output_scrollbox "$action_title" podman pod inspect "$pod_id" | jq '.' # Pipe to jq for pretty printing
                elif [ "$podman_action" == "rm" ]; then
                    if confirm_dialog "LANG_CONFIRM_ACTION" "LANG_ARE_YOU_SURE"; then
                        display_message "$(get_string "LANG_INFO")" "$(get_string "$operation_cmd_key" "$pod_name_for_msg")"
                        if podman pod "$podman_action" "$pod_id"; then
                            display_message "$(get_string "LANG_SUCCESS")" "$(get_string "$success_key" "$pod_name_for_msg")"
                        else
                            display_error "$(get_string "$fail_key" "$pod_name_for_msg")"
                        fi
                    fi
                else # start, stop, restart, kill, pause, unpause
                    display_message "$(get_string "LANG_INFO")" "$(get_string "$operation_cmd_key" "$pod_name_for_msg")"
                    if podman pod "$podman_action" "$pod_id"; then
                        display_message "$(get_string "LANG_SUCCESS")" "$(get_string "$success_key" "$pod_name_for_msg")"
                    else
                        display_error "$(get_string "$fail_key" "$pod_name_for_msg")"
                    fi
                fi
                ;;

            0) # Back
                break
                ;;
            *)
                display_error "$(get_string "LANG_INVALID_OPTION")"
                ;;
        esac
    done
}

handle_manage_pods
