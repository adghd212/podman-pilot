#!/bin/bash
# Manage Containers Module for Podman Pilot

list_containers_for_selection() {
    local title_key="$1" # e.g. LANG_CONTAINERS_SELECT_CONTAINER
    local list_all="$2" # true to list all, false for running only
    local ps_args=()
    [[ "$list_all" == "true" ]] && ps_args+=("-a")

    # Format: ID Name Image Status Ports Pod
    mapfile -t container_lines < <(podman ps "${ps_args[@]}" --format "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null)
    
    if [ ${#container_lines[@]} -eq 0 ]; then
        display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_CONTAINERS_NO_CONTAINERS_FOUND")"
        return 1
    fi

    local options=()
    for line in "${container_lines[@]}"; do
        local con_id con_name con_image con_status
        IFS=$'\t' read -r con_id con_name con_image con_status <<< "$line"
        # Shorten image name if too long
        [[ ${#con_image} -gt 30 ]] && con_image="${con_image:0:27}..."
        options+=("$con_id" "Name: $con_name (Status: $con_status, Image: $con_image)")
    done
    
    local selected_con_id
    selected_con_id=$(select_from_list "$(get_string "$title_key")" \
                                     "$(get_string "LANG_CONTAINERS_SELECT_CONTAINER")" \
                                     "20" "$((${#options[@]}/2))" "80" "" \
                                     "${options[@]}")
    local exit_status=$?
    if [ $exit_status -eq 0 ] && [ -n "$selected_con_id" ]; then
        echo "$selected_con_id"
        return 0
    else
        return 1 # Cancelled or no selection
    fi
}


handle_manage_containers() {
    while true; do
        local options=(
            "1" "$(get_string "LANG_CONTAINERS_LIST_ALL")"
            "2" "$(get_string "LANG_CONTAINERS_LIST_RUNNING")"
            "3" "$(get_string "LANG_CONTAINERS_CREATE")"
            "4" "$(get_string "LANG_CONTAINERS_START")"
            "5" "$(get_string "LANG_CONTAINERS_STOP")"
            "6" "$(get_string "LANG_CONTAINERS_RESTART")"
            "7" "$(get_string "LANG_CONTAINERS_KILL")"
            "8" "$(get_string "LANG_CONTAINERS_PAUSE")"
            "9" "$(get_string "LANG_CONTAINERS_UNPAUSE")"
            "10" "$(get_string "LANG_CONTAINERS_LOGS")"
            "11" "$(get_string "LANG_CONTAINERS_INSPECT")"
            "12" "$(get_string "LANG_CONTAINERS_EXEC")"
            "13" "$(get_string "LANG_CONTAINERS_DELETE")"
            "14" "$(get_string "LANG_CONTAINERS_PRUNE")"
            "0" "$(get_string "LANG_BACK")"
        )

        CHOICE=$(select_from_list "LANG_CONTAINERS_MENU_TITLE" "LANG_SELECT_AN_OPTION" "22" "15" "70" "" "${options[@]}")
        exit_status=$?
        if [ $exit_status -ne 0 ]; then break; fi

        case $CHOICE in
            1) # List All Containers
                show_output_scrollbox "$(get_string "LANG_CONTAINERS_LIST_ALL")" podman ps -a --format "table {{.ID}}\\t{{.Names}}\\t{{.Image}}\\t{{.Command}}\\t{{.Status}}\\t{{.Ports}}"
                ;;
            2) # List Running Containers
                show_output_scrollbox "$(get_string "LANG_CONTAINERS_LIST_RUNNING")" podman ps --format "table {{.ID}}\\t{{.Names}}\\t{{.Image}}\\t{{.Command}}\\t{{.Status}}\\t{{.Ports}}"
                ;;
            3) # Create Container (Basic)
                # Select image first
                local image_id_for_create image_name_for_create
                image_id_for_create=$(list_images_for_selection "LANG_CONTAINERS_SELECT_IMAGE_FOR_CREATE")
                if [ -z "$image_id_for_create" ]; then continue; fi
                image_name_for_create=$(podman image inspect "$image_id_for_create" --format "{{index .RepoTags 0}}" 2>/dev/null || echo "$image_id_for_create")

                local con_name con_ports con_volumes con_envs con_cmd con_pod_name run_detached
                con_name=$(get_input "LANG_CONTAINERS_ENTER_NAME" "")
                con_ports=$(get_input "LANG_CONTAINERS_ENTER_PORTS" "") # e.g., 8080:80,443:443
                con_volumes=$(get_input "LANG_CONTAINERS_ENTER_VOLUMES" "") # e.g., /host:/cont:Z,/other:/else
                con_envs=$(get_input "LANG_CONTAINERS_ENTER_ENV_VARS" "") # e.g., K1=V1,K2=V2
                con_cmd=$(get_input "LANG_CONTAINERS_ENTER_COMMAND" "")
                con_pod_name=$(get_input "LANG_CONTAINERS_ASSIGN_TO_POD" "")
                
                if confirm_dialog "LANG_INFO" "LANG_CONTAINERS_DETACH_MODE"; then
                    run_detached=true
                else
                    run_detached=false
                fi

                local run_args=()
                $run_detached && run_args+=("-d")
                [ -n "$con_name" ] && run_args+=("--name" "$con_name")
                [ -n "$con_pod_name" ] && run_args+=("--pod" "$con_pod_name")

                [ -n "$con_ports" ] && IFS=',' read -ra ports_arr <<< "$con_ports" && for p in "${ports_arr[@]}"; do run_args+=("-p" "$p"); done
                [ -n "$con_volumes" ] && IFS=',' read -ra vols_arr <<< "$con_volumes" && for v in "${vols_arr[@]}"; do run_args+=("-v" "$v"); done
                [ -n "$con_envs" ] && IFS=',' read -ra envs_arr <<< "$con_envs" && for e in "${envs_arr[@]}"; do run_args+=("-e" "$e"); done
                
                run_args+=("$image_name_for_create") # Image name or ID
                [ -n "$con_cmd" ] && run_args+=($con_cmd) # Command and its args (bash word splitting)

                display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_CONTAINERS_CREATING")"
                if new_con_id=$(podman run "${run_args[@]}"); then
                    display_message "$(get_string "LANG_SUCCESS")" "$(get_string "LANG_CONTAINERS_CREATED_SUCCESS" "${new_con_id:0:12}")"
                else
                    display_error "$(get_string "LANG_CONTAINERS_CREATE_FAILED")"
                fi
                ;;
            4|5|6|7|8|9|10|11|12|13) # Operations requiring container selection
                local action_title action_lang_key con_id operation_cmd_key success_key fail_key podman_action list_all_con="true"
                
                case $CHOICE in
                    4) action_title="LANG_CONTAINERS_START"; podman_action="start"; success_key="LANG_CONTAINERS_STARTED_SUCCESS"; fail_key="LANG_CONTAINERS_START_FAILED"; operation_cmd_key="LANG_CONTAINERS_STARTING"; list_all_con="true" ;;
                    5) action_title="LANG_CONTAINERS_STOP"; podman_action="stop"; success_key="LANG_CONTAINERS_STOPPED_SUCCESS"; fail_key="LANG_CONTAINERS_STOP_FAILED"; operation_cmd_key="LANG_CONTAINERS_STOPPING"; list_all_con="false" ;; # Usually stop running ones
                    6) action_title="LANG_CONTAINERS_RESTART"; podman_action="restart"; success_key="LANG_OPERATION_SUCCESSFUL"; fail_key="LANG_OPERATION_FAILED"; operation_cmd_key="LANG_CONTAINERS_RESTARTING"; list_all_con="false" ;;
                    7) action_title="LANG_CONTAINERS_KILL"; podman_action="kill"; success_key="LANG_OPERATION_SUCCESSFUL"; fail_key="LANG_OPERATION_FAILED"; operation_cmd_key="LANG_CONTAINERS_KILLING"; list_all_con="false" ;;
                    8) action_title="LANG_CONTAINERS_PAUSE"; podman_action="pause"; success_key="LANG_OPERATION_SUCCESSFUL"; fail_key="LANG_OPERATION_FAILED"; operation_cmd_key="LANG_CONTAINERS_PAUSING"; list_all_con="false" ;;
                    9) action_title="LANG_CONTAINERS_UNPAUSE"; podman_action="unpause"; success_key="LANG_OPERATION_SUCCESSFUL"; fail_key="LANG_OPERATION_FAILED"; operation_cmd_key="LANG_CONTAINERS_UNPAUSING"; list_all_con="false" ;;
                    10) action_title="LANG_CONTAINERS_LOGS"; podman_action="logs"; operation_cmd_key="LANG_CONTAINERS_VIEWING_LOGS"; list_all_con="true" ;;
                    11) action_title="LANG_CONTAINERS_INSPECT"; podman_action="inspect"; operation_cmd_key="LANG_CONTAINERS_INSPECTING"; list_all_con="true" ;;
                    12) action_title="LANG_CONTAINERS_EXEC"; podman_action="exec"; operation_cmd_key="LANG_CONTAINERS_EXEC"; list_all_con="false" ;; # Exec in running
                    13) action_title="LANG_CONTAINERS_DELETE"; podman_action="rm"; success_key="LANG_CONTAINERS_DELETED_SUCCESS"; fail_key="LANG_CONTAINERS_DELETE_FAILED"; operation_cmd_key="LANG_CONTAINERS_DELETING"; list_all_con="true" ;;
                esac

                con_id=$(list_containers_for_selection "$action_title" "$list_all_con")
                if [ -z "$con_id" ]; then continue; fi
                
                local con_name_for_msg
                con_name_for_msg=$(podman inspect "$con_id" --format "{{.Name}}" 2>/dev/null || echo "$con_id")

                if [ "$podman_action" == "inspect" ]; then
                    if ! check_command "jq" "LANG_JQ_REQUIRED"; then continue; fi
                    show_output_scrollbox "$(get_string "$operation_cmd_key" "$con_name_for_msg")" podman inspect "$con_id" | jq '.'
                elif [ "$podman_action" == "logs" ]; then
                    # For logs, --follow can be interactive. Use programbox or just show last N lines.
                    # show_output_scrollbox will show all current logs. Add --tail 100 if needed.
                    display_message "$(get_string "LANG_INFO")" "$(get_string "$operation_cmd_key" "$con_name_for_msg")"
                    show_output_scrollbox "$(get_string "$operation_cmd_key" "$con_name_for_msg")" podman logs "$con_id" --tail 200
                elif [ "$podman_action" == "exec" ]; then
                    local exec_cmd
                    exec_cmd=$(get_input "$(get_string "LANG_CONTAINERS_ENTER_EXEC_CMD" "$con_name_for_msg")" "sh")
                    if [ -n "$exec_cmd" ]; then
                        # For interactive exec, we need to drop out of dialog temporarily
                        clear
                        echo "Executing '$exec_cmd' in container '$con_name_for_msg'. Type 'exit' to return."
                        podman exec -it "$con_id" $exec_cmd # Bash word splitting for $exec_cmd
                        echo "Exited from container. Press Enter to return to menu."
                        read -r
                        clear
                    fi
                elif [ "$podman_action" == "rm" ]; then
                     if confirm_dialog "LANG_CONFIRM_ACTION" "$(get_string "LANG_ARE_YOU_SURE") $(get_string "$operation_cmd_key" "$con_name_for_msg")"; then
                        display_message "$(get_string "LANG_INFO")" "$(get_string "$operation_cmd_key" "$con_name_for_msg")"
                        if podman rm "$con_id"; then
                            display_message "$(get_string "LANG_SUCCESS")" "$(get_string "$success_key" "$con_name_for_msg")"
                        else
                            display_error "$(get_string "$fail_key" "$con_name_for_msg")"
                        fi
                    fi
                else # start, stop, restart, kill, pause, unpause
                    display_message "$(get_string "LANG_INFO")" "$(get_string "$operation_cmd_key" "$con_name_for_msg")"
                    if podman "$podman_action" "$con_id"; then
                        display_message "$(get_string "LANG_SUCCESS")" "$(get_string "$success_key" "$con_name_for_msg")"
                    else
                        display_error "$(get_string "$fail_key" "$con_name_for_msg")"
                    fi
                fi
                ;;
            14) # Prune Stopped Containers
                if confirm_dialog "LANG_CONFIRM_ACTION" "$(get_string "LANG_ARE_YOU_SURE") $(get_string "LANG_CONTAINERS_PRUNING")"; then
                    display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_CONTAINERS_PRUNING")"
                    if podman container prune -f; then
                        display_message "$(get_string "LANG_SUCCESS")" "$(get_string "LANG_CONTAINERS_PRUNED_SUCCESS")"
                    else
                        display_error "$(get_string "LANG_CONTAINERS_PRUNE_FAILED")"
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

handle_manage_containers
