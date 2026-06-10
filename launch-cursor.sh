#!/bin/bash

BASE_DIR="$HOME/Library/Application Support"
DEFAULT_APP="/Applications/Cursor.app/Contents/MacOS/Cursor"

while true; do
  clear
  echo "========================================"
  echo "      CURSOR ALL-IN-ONE ENGINE          "
  echo "========================================"
  
  profiles=()
  count=0
  
  echo "p) Launch Personal Account (Default)"
  echo "----------------------------------------"
  
  # Scan and index sandboxed profiles
  while IFS= read -r dir; do
    if [ -d "$dir" ]; then
      profile_name=$(basename "$dir" | sed 's/Cursor-//')
      profiles+=("$profile_name")
      echo "$count) Launch Profile: [$profile_name]"
      ((count++))
    fi
  done < <(find "$BASE_DIR" -maxdepth 1 -name "Cursor-*" -type d 2>/dev/null)
  
  echo "========================================"
  echo "c) Create New Profile"
  echo "r) Rename a Profile"
  echo "d) Delete a Profile"
  echo "q) Quit"
  echo "========================================"
  
  read -p "Choose an action: " choice

  # CONCURRENCY KILL-SWITCH
  if [[ "$choice" =~ ^[0-9p]+$ ]]; then
    if pgrep -q -x "Cursor"; then
      echo "----------------------------------------"
      echo "CRITICAL: An existing Cursor instance is running."
      read -p "Kill it to prevent concurrent ToS flagging? (y/n): " kill_choice
      if [ "$kill_choice" = "y" ]; then
        killall Cursor
        sleep 1.5
      else
        echo "Launch aborted for safety. Press enter."; read
        continue
      fi
    fi
  fi

  case $choice in
    q)
      echo "Exiting."
      exit 0
      ;;
    p)
      echo "Launching Default Personal Profile..."
      "$DEFAULT_APP" & disown
      kill -9 $PPID
      ;;
    c)
      read -p "Enter unique name for new profile: " new_name
      new_name=$(echo "$new_name" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')
      if [ -z "$new_name" ]; then
        echo "Invalid name. Press enter to retry."; read
        continue
      fi
      NEW_PATH="$BASE_DIR/Cursor-$new_name"
      if [ -d "$NEW_PATH" ]; then
        echo "Profile already exists! Press enter."; read
      else
        mkdir -p "$NEW_PATH/User"
        [ -f "$BASE_DIR/Cursor/User/settings.json" ] && cp "$BASE_DIR/Cursor/User/settings.json" "$NEW_PATH/User/settings.json"
        
        # PRIVACY INJECTION (Safe JSON Merge)
        python3 -c "import json, os; f='$NEW_PATH/User/settings.json'; d = json.load(open(f)) if os.path.exists(f) and os.path.getsize(f) > 0 else {}; d.update({'cursor.general.privacyMode': True, 'telemetry.telemetryLevel': 'off'}); json.dump(d, open(f, 'w'), indent=4)"

        echo "Profile [$new_name] created with Privacy Mode enforced."
        sleep 1.5
      fi
      ;;
    r)
      read -p "Enter number of the profile to rename: " num
      if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 0 && "$num" -lt "${#profiles[@]}" ]]; then
        old_name="${profiles[num]}"
        read -p "Enter NEW name for [$old_name]: " new_name
        new_name=$(echo "$new_name" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')
        if [ -n "$new_name" ]; then
          mv "$BASE_DIR/Cursor-$old_name" "$BASE_DIR/Cursor-$new_name"
          echo "Renamed successfully."
          sleep 1
        fi
      else
        echo "Invalid choice. Must be a valid number. Press enter."; read
      fi
      ;;
    d)
      read -p "Enter number of the profile to DELETE: " num
      if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 0 && "$num" -lt "${#profiles[@]}" ]]; then
        target_name="${profiles[num]}"
        read -p "Are you sure you want to completely erase [$target_name]? (y/n): " confirm
        if [ "$confirm" = "y" ]; then
          rm -rf "$BASE_DIR/Cursor-$target_name"
          echo "Profile deleted."
          sleep 1
        fi
      else
        echo "Invalid choice. Must be a valid number. Press enter."; read
      fi
      ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 0 && "$choice" -lt "${#profiles[@]}" ]]; then
        target_name="${profiles[choice]}"
        echo "Launching Profile: [$target_name]..."
        "$DEFAULT_APP" --user-data-dir="$BASE_DIR/Cursor-$target_name" & disown
        kill -9 $PPID
      else
        echo "Invalid selection. Press enter."; read
      fi
      ;;
  esac
done
