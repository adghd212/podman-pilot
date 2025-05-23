#!/bin/bash
# Manage Images Module for Podman Pilot

list_images_for_selection() {
    local title_key="$1" # e.g. LANG_IMAGES_SELECT_TO_DELETE
    # Format: ID Repository Tag CreatedAt Size
    mapfile -t image_lines < <(podman images --format "{{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null)
    
    if [ ${#image_lines[@]} -eq 0 ]; then
        display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_IMAGES_NO_IMAGES_FOUND")"
        return 1
    fi

    local options=()
    for line in "${image_lines[@]}"; do
        local img_id img_repo img_tag img_size
        IFS=$'\t' read -r img_id img_repo img_tag img_size <<< "$line"
        local display_name="$img_repo:$img_tag ($img_size)"
        # If repo or tag is <none>, handle display
        if [[ "$img_repo" == "<none>" || "$img_tag" == "<none>" ]]; then
            display_name="$img_id (Untagged/Unnamed) ($img_size)"
        fi
        options+=("$img_id" "$display_name")
    done
    
    local selected_img_id
    selected_img_id=$(select_from_list "$(get_string "$title_key")" \
                                     "$(get_string "LANG_IMAGES_SELECT_IMAGE")" \
                                     "20" "$((${#options[@]}/2))" "70" "" \
                                     "${options[@]}")
    local exit_status=$?
    if [ $exit_status -eq 0 ] && [ -n "$selected_img_id" ]; then
        echo "$selected_img_id"
        return 0
    else
        return 1 # Cancelled or no selection
    fi
}


handle_manage_images() {
    while true; do
        local options=(
            "1" "$(get_string "LANG_IMAGES_LIST")"
            "2" "$(get_string "LANG_IMAGES_PULL")"
            "3" "$(get_string "LANG_IMAGES_SEARCH")"
            "4" "$(get_string "LANG_IMAGES_INSPECT")"
            "5" "$(get_string "LANG_IMAGES_REMOVE")"
            "6" "$(get_string "LANG_IMAGES_PRUNE")"
            "0" "$(get_string "LANG_BACK")"
        )

        CHOICE=$(select_from_list "LANG_IMAGES_MENU_TITLE" "LANG_SELECT_AN_OPTION" "18" "7" "60" "" "${options[@]}")
        exit_status=$?
        if [ $exit_status -ne 0 ]; then break; fi

        case $CHOICE in
            1) # List Images
                show_output_scrollbox "$(get_string "LANG_IMAGES_LIST")" podman images --format "table {{.ID}}\\t{{.Repository}}\\t{{.Tag}}\\t{{.CreatedAt}}\\t{{.Size}}"
                ;;
            2) # Pull Image
                local image_name
                image_name=$(get_input "LANG_IMAGES_ENTER_NAME_TAG" "nginx:latest")
                if [ -n "$image_name" ]; then
                    display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_IMAGES_PULLING" "$image_name")"
                    # Show output in a programbox for progress
                    # podman pull "$image_name" | dialog --programbox "$(get_string "LANG_IMAGES_PULLING" "$image_name")" 20 70
                    # For better UX, capture output and then display summary
                    local pull_output temp_file
                    temp_file=$(mktemp)
                    if podman pull "$image_name" > "$temp_file" 2>&1; then
                        dialog --title "$(get_string "LANG_IMAGES_PULLED_SUCCESS" "$image_name")" --textbox "$temp_file" 20 70
                        clear
                        display_message "$(get_string "LANG_SUCCESS")" "$(get_string "LANG_IMAGES_PULLED_SUCCESS" "$image_name")"
                    else
                        dialog --title "$(get_string "LANG_IMAGES_PULL_FAILED" "$image_name")" --textbox "$temp_file" 20 70
                        clear
                        display_error "$(get_string "LANG_IMAGES_PULL_FAILED" "$image_name")"
                    fi
                    rm "$temp_file"
                else
                    display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_ACTION_CANCELLED")"
                fi
                ;;
            3) # Search for Image
                local search_term
                search_term=$(get_input "LANG_IMAGES_SEARCH_TERM" "nginx")
                if [ -n "$search_term" ]; then
                    display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_IMAGES_SEARCHING" "$search_term")"
                    show_output_scrollbox "$(get_string "LANG_IMAGES_SEARCHING" "$search_term")" podman search "$search_term" --format "table {{.Index}}\\t{{.Name}}\\t{{.Description}}\\t{{.Stars}}\\t{{.Official}}" --limit 20
                else
                     display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_ACTION_CANCELLED")"
                fi
                ;;
            4) # Inspect Image
                local img_id_to_inspect img_name_for_msg
                img_id_to_inspect=$(list_images_for_selection "LANG_IMAGES_INSPECT")
                if [ -n "$img_id_to_inspect" ]; then
                    if ! check_command "jq" "LANG_JQ_REQUIRED"; then continue; fi
                    img_name_for_msg=$(podman image inspect "$img_id_to_inspect" --format "{{index .RepoTags 0}}" 2>/dev/null || echo "$img_id_to_inspect")
                    display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_IMAGES_INSPECTING" "$img_name_for_msg")"
                    show_output_scrollbox "$(get_string "LANG_IMAGES_INSPECTING" "$img_name_for_msg")" podman image inspect "$img_id_to_inspect" | jq '.'
                fi
                ;;
            5) # Remove Image
                local img_id_to_remove img_name_for_msg
                img_id_to_remove=$(list_images_for_selection "LANG_IMAGES_REMOVE")
                 if [ -n "$img_id_to_remove" ]; then
                    img_name_for_msg=$(podman image inspect "$img_id_to_remove" --format "{{index .RepoTags 0}}" 2>/dev/null || echo "$img_id_to_remove")
                    if confirm_dialog "LANG_CONFIRM_ACTION" "$(get_string "LANG_ARE_YOU_SURE") $(get_string "LANG_IMAGES_DELETING" "$img_name_for_msg")"; then
                        display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_IMAGES_DELETING" "$img_name_for_msg")"
                        if podman rmi "$img_id_to_remove"; then
                            display_message "$(get_string "LANG_SUCCESS")" "$(get_string "LANG_IMAGES_DELETED_SUCCESS" "$img_name_for_msg")"
                        else
                            display_error "$(get_string "LANG_IMAGES_DELETE_FAILED" "$img_name_for_msg")"
                        fi
                    fi
                fi
                ;;
            6) # Prune Unused Images
                if confirm_dialog "LANG_CONFIRM_ACTION" "$(get_string "LANG_ARE_YOU_SURE") $(get_string "LANG_IMAGES_PRUNING")"; then
                    display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_IMAGES_PRUNING")"
                    if podman image prune -a -f; then # -a for all unused, -f for force
                        display_message "$(get_string "LANG_SUCCESS")" "$(get_string "LANG_IMAGES_PRUNED_SUCCESS")"
                    else
                        display_error "$(get_string "LANG_IMAGES_PRUNE_FAILED")"
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

handle_manage_images
