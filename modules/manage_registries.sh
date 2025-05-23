#!/bin/bash
# Manage Image Registries Module for Podman Pilot

# This script is sourced by podman-pilot.sh

USER_REGISTRIES_CONF_D="${HOME}/.config/containers/registries.conf.d" # Podman >= v3 prefer .d files
USER_REGISTRIES_CONF="${HOME}/.config/containers/registries.conf"     # Older podman
SYSTEM_REGISTRIES_CONF="/etc/containers/registries.conf"

# Ensure registries.conf.d directory exists for user
ensure_user_registries_d_exists() {
    if [ ! -d "$USER_REGISTRIES_CONF_D" ]; then
        mkdir -p "$USER_REGISTRIES_CONF_D"
        if [ $? -ne 0 ]; then
            display_error "LANG_ERROR" "Failed to create directory $USER_REGISTRIES_CONF_D"
            return 1
        fi
    fi
    return 0
}

# Function to read search registries from user config (new .d format preferred)
get_user_search_registries() {
    local registries=()
    if [ -d "$USER_REGISTRIES_CONF_D" ]; then
        for conf_file in "$USER_REGISTRIES_CONF_D"/*.conf; do
            if [ -f "$conf_file" ]; then
                # This is a simplification; real TOML parsing is complex in bash
                # Assuming simple structure for search registries:
                # [[registries]]
                #   prefix = "example.com" (or location)
                #   location = "example.com" 
                # Or in registries.conf:
                # [registries.search]
                # registries = ["reg1", "reg2"]
                while IFS= read -r line; do
                    if [[ "$line" == *'registries = ['* ]]; then
                        line="${line#*= \[\"}" # Remove up to opening quote
                        line="${line%\"\]*}"    # Remove from closing quote
                        IFS=',' read -ra found_registries <<< "$line"
                        for reg in "${found_registries[@]}"; do
                            registries+=("$(echo "$reg" | xargs)") # xargs to trim whitespace
                        done
                        break # Assuming one search block per .conf.d file for simplicity or main file
                    fi
                done < "$conf_file"
            fi
        done
    fi
    # Fallback or addition from old registries.conf if .d is empty or for compatibility
    if [ -f "$USER_REGISTRIES_CONF" ]; then
         while IFS= read -r line; do
            if [[ "$line" == *'registries = ['* ]]; then
                line="${line#*= \[\"}" 
                line="${line%\"\]*}"    
                IFS=',' read -ra found_registries <<< "$line"
                for reg in "${found_registries[@]}"; do
                     # Avoid duplicates if both .conf and .d exist and have same entries
                    if ! printf '%s\n' "${registries[@]}" | grep -qx "$(echo "$reg" | xargs)"; then
                        registries+=("$(echo "$reg" | xargs)")
                    fi
                done
                break 
            fi
        done < "$USER_REGISTRIES_CONF"
    fi
    echo "${registries[@]}"
}


# Add a search registry to user's config
# Creates a file like 50-my-custom-registry.conf in registries.conf.d
add_user_search_registry() {
    local new_registry="$1"
    ensure_user_registries_d_exists || return 1

    # Check if already exists
    local existing_registries
    existing_registries=($(get_user_search_registries))
    for reg in "${existing_registries[@]}"; do
        if [[ "$reg" == "$new_registry" ]]; then
            display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_REGISTRIES_ALREADY_EXISTS" "$new_registry")"
            return 0 # Already exists
        fi
    done

    # Create a new .conf.d file for this registry to keep things clean
    # Use a simple naming scheme, e.g., 50-search-<sanitized_registry_name>.conf
    local sanitized_name
    sanitized_name=$(echo "$new_registry" | tr -c '[:alnum:].-' '_') # Sanitize for filename
    local new_conf_file="${USER_REGISTRIES_CONF_D}/50-search-${sanitized_name}.conf"
    
    # This adds the new registry as a search registry.
    # For a single registry, the format is:
    # unqualified-search-registries = ["example.com", "docker.io"]
    # This is a simplification; Podman's registries.conf can be complex.
    # A more robust way might be to manage one central search list.
    # For now, let's assume we are just adding to the search list.
    # The *correct* way to add a search registry if others exist is to modify the existing list.
    # For simplicity, if we add a new one, we'll create a new file.
    # If a global search list is managed in one file (e.g. 00-search.conf), that file should be edited.

    # Create a config file that adds this to the search registries.
    # This is complex because the `unqualified-search-registries` is a global list.
    # A better approach for individual additions via .conf.d might be to define them as type "search".
    # Example from `man containers-registries.conf`:
    # [[registry]]
    #   location = "example.com"
    #   # This registry is a "search" registry.
    #   # It is not recommended to use this option.
    #   # The `unqualified-search-registries` list in `/etc/containers/registries.conf`
    #   # is the preferred way to configure search registries.
    #
    # Given the recommendation, we should ideally edit the main list.
    # For user-level, if no USER_REGISTRIES_CONF exists, create it with the search.
    # If it exists, parse and add. This is hard in Bash.

    # Simplification: We will add to unqualified-search-registries in a new file.
    # This might not be the "additive" way podman expects for .conf.d unless it merges these lists.
    # According to docs, unqualified-search-registries is read from the first file that sets it.
    # So this approach of multiple files defining it won't work well.
    
    # Let's manage a single file for search registries at user level for simplicity.
    local user_search_conf="${USER_REGISTRIES_CONF_D}/01-podman-pilot-search.conf"
    
    local current_search_list=()
    if [ -f "$user_search_conf" ]; then
        # Crude parse of 'unqualified-search-registries = ["reg1", "reg2"]'
        local line_content
        line_content=$(grep 'unqualified-search-registries' "$user_search_conf" | head -n 1)
        if [[ "$line_content" == *'unqualified-search-registries = ['* ]]; then
            line_content="${line_content#*= \[\"}"
            line_content="${line_content%\"\]*}"
            IFS=',' read -ra current_search_list <<< "$line_content"
            # Trim whitespace
            for i in "${!current_search_list[@]}"; do
                current_search_list[$i]="$(echo "${current_search_list[$i]}" | xargs)"
            done
        fi
    fi
    
    # Add new registry if not already there
    local found=false
    for item in "${current_search_list[@]}"; do
        if [[ "$item" == "$new_registry" ]]; then
            found=true
            break
        fi
    done
    if ! $found; then
        current_search_list+=("$new_registry")
    else
        display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_REGISTRIES_ALREADY_EXISTS" "$new_registry")"
        return 0
    fi

    # Rebuild the string: unqualified-search-registries = ["reg1", "reg2"]
    local new_list_str="unqualified-search-registries = ["
    for i in "${!current_search_list[@]}"; do
        new_list_str+="\"${current_search_list[$i]}\""
        if [ $i -lt $((${#current_search_list[@]} - 1)) ]; then
            new_list_str+=", "
        fi
    done
    new_list_str+="]"

    echo "$new_list_str" > "$user_search_conf"
    if [ $? -eq 0 ]; then
        display_message "$(get_string "LANG_SUCCESS")" "$(get_string "LANG_REGISTRIES_MODIFIED_SUCCESS")"
    else
        display_error "$(get_string "LANG_REGISTRIES_MODIFIED_FAILED")"
    fi
}

# Remove a search registry from user's config
remove_user_search_registry() {
    local registry_to_remove="$1"
    local user_search_conf="${USER_REGISTRIES_CONF_D}/01-podman-pilot-search.conf"
    
    if [ ! -f "$user_search_conf" ]; then
        display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_REGISTRIES_NOT_FOUND" "$registry_to_remove")"
        return 1
    fi

    local current_search_list=()
    local line_content
    line_content=$(grep 'unqualified-search-registries' "$user_search_conf" | head -n 1)
    if [[ "$line_content" == *'unqualified-search-registries = ['* ]]; then
        line_content="${line_content#*= \[\"}"
        line_content="${line_content%\"\]*}"
        IFS=',' read -ra current_search_list <<< "$line_content"
        for i in "${!current_search_list[@]}"; do
            current_search_list[$i]="$(echo "${current_search_list[$i]}" | xargs)"
        done
    fi

    local new_search_list=()
    local found=false
    for item in "${current_search_list[@]}"; do
        if [[ "$item" == "$registry_to_remove" ]]; then
            found=true
        else
            new_search_list+=("$item")
        fi
    done

    if ! $found; then
        display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_REGISTRIES_NOT_FOUND" "$registry_to_remove")"
        return 1
    fi

    if [ ${#new_search_list[@]} -eq 0 ]; then
        rm -f "$user_search_conf" # Remove file if list is empty
    else
        local new_list_str="unqualified-search-registries = ["
        for i in "${!new_search_list[@]}"; do
            new_list_str+="\"${new_search_list[$i]}\""
            if [ $i -lt $((${#new_search_list[@]} - 1)) ]; then
                new_list_str+=", "
            fi
        done
        new_list_str+="]"
        echo "$new_list_str" > "$user_search_conf"
    fi

    if [ $? -eq 0 ]; then
        display_message "$(get_string "LANG_SUCCESS")" "$(get_string "LANG_REGISTRIES_MODIFIED_SUCCESS")"
    else
        display_error "$(get_string "LANG_REGISTRIES_MODIFIED_FAILED")"
    fi
}


handle_manage_registries() {
    source "${SCRIPT_DIR}/config/registries.conf" # Load REGISTRY_OPTIONS

    while true; do
        local options=(
            "1" "$(get_string "LANG_REGISTRIES_VIEW_CURRENT")"
            "2" "$(get_string "LANG_REGISTRIES_ADD_SEARCH")"
            "3" "$(get_string "LANG_REGISTRIES_REMOVE_SEARCH")"
            # "4" "$(get_string "LANG_REGISTRIES_ADD_INSECURE")" # More complex, involves [[registry]] blocks
            # "5" "$(get_string "LANG_REGISTRIES_REMOVE_INSECURE")"
            "0" "$(get_string "LANG_BACK")"
        )

        CHOICE=$(select_from_list "LANG_REGISTRIES_MENU_TITLE" "LANG_SELECT_AN_OPTION" "18" "5" "70" "" "${options[@]}")
        exit_status=$?

        if [ $exit_status -ne 0 ]; then break; fi

        case $CHOICE in
            1) # View Current Registries
                local user_conf_display="${USER_REGISTRIES_CONF_D}/ (and ${USER_REGISTRIES_CONF} if exists)"
                local sys_conf_display="$SYSTEM_REGISTRIES_CONF"
                
                local output_text=""
                output_text+="$(get_string "LANG_REGISTRIES_USER_CONF_PATH" "$user_conf_display")\n"
                output_text+="--------------------------------------------------\n"
                if [ -d "$USER_REGISTRIES_CONF_D" ]; then
                    for f in "$USER_REGISTRIES_CONF_D"/*.conf; do
                        [ -e "$f" ] || continue # handle no files case
                        output_text+="Content of $f:\n"
                        output_text+="$(cat "$f" 2>/dev/null || echo 'Error reading file')\n\n"
                    done
                else
                     output_text+="$(get_string "LANG_NO_USER_CONF")\n\n"
                fi
                 if [ -f "$USER_REGISTRIES_CONF" ]; then # Also show old file if it exists
                    output_text+="Content of $USER_REGISTRIES_CONF:\n"
                    output_text+="$(cat "$USER_REGISTRIES_CONF" 2>/dev/null || echo 'Error reading file')\n\n"
                fi


                output_text+="\n$(get_string "LANG_REGISTRIES_SYSTEM_CONF_PATH" "$sys_conf_display")\n"
                output_text+="--------------------------------------------------\n"
                if [ -f "$SYSTEM_REGISTRIES_CONF" ]; then
                    output_text+="$(cat "$SYSTEM_REGISTRIES_CONF" 2>/dev/null || echo 'Error reading file')\n"
                else
                    output_text+="System registries.conf not found or not readable.\n"
                fi
                
                echo -e "$output_text" | dialog --backtitle "$(get_string "LANG_MAIN_MENU_BACKTITLE")" \
                                               --title "$(get_string "LANG_REGISTRIES_VIEW_CURRENT")" \
                                               --ok-label "$(get_string "LANG_OK")" \
                                               --programbox 25 80
                clear
                ;;
            2) # Add Search Registry
                ensure_user_registries_d_exists || continue
                local predefined_options=()
                for i in "${!REGISTRY_OPTIONS[@]}"; do
                    local url_desc="${REGISTRY_OPTIONS[$i]}" # "url (desc)"
                    local url="${url_desc%% *}" # extract URL
                    predefined_options+=("$url" "$url_desc")
                done
                predefined_options+=("CUSTOM" "$(get_string "LANG_REGISTRIES_CUSTOM_OPTION")")

                local selected_reg_tag
                selected_reg_tag=$(select_from_list "LANG_REGISTRIES_ADD_SEARCH" \
                                                  "LANG_REGISTRIES_PREDEFINED_TITLE" \
                                                  "20" "$((${#predefined_options[@]}/2))" "70" "" \
                                                  "${predefined_options[@]}")
                
                if [ -n "$selected_reg_tag" ]; then
                    local new_registry_url
                    if [ "$selected_reg_tag" == "CUSTOM" ]; then
                        new_registry_url=$(get_input "LANG_REGISTRIES_ENTER_URL" "")
                        if [ -z "$new_registry_url" ]; then
                             display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_ACTION_CANCELLED")"
                             continue
                        fi
                    else
                        new_registry_url="$selected_reg_tag" # Tag is the URL itself
                    fi

                    if [[ "$new_registry_url" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9](:[0-9]+)?(/.*)?$ ]]; then
                        add_user_search_registry "$new_registry_url"
                    else
                        display_error "$(get_string "LANG_REGISTRIES_INVALID_URL")"
                    fi
                fi
                ;;
            3) # Remove Search Registry
                ensure_user_registries_d_exists || continue
                local current_regs_array
                current_regs_array=($(get_user_search_registries))
                if [ ${#current_regs_array[@]} -eq 0 ]; then
                    display_message "$(get_string "LANG_INFO")" "$(get_string "LANG_NO_ITEMS_FOUND")"
                    continue
                fi
                
                local select_options=()
                for reg in "${current_regs_array[@]}"; do
                    select_options+=("$reg" "$reg") # tag and item are the same
                done

                local reg_to_remove
                reg_to_remove=$(select_from_list "LANG_REGISTRIES_REMOVE_SEARCH" \
                                               "LANG_REGISTRIES_SELECT_TO_REMOVE" \
                                               "15" "$((${#select_options[@]}/2))" "60" "" \
                                               "${select_options[@]}")
                if [ -n "$reg_to_remove" ]; then
                    remove_user_search_registry "$reg_to_remove"
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

handle_manage_registries
