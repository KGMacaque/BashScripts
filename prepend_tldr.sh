#!/bin/bash
                                      ##############################
                                      ###  Created By: KGMacaque ###
                                      ############################## 

while true; do
  read -p "Enter your command (or Ctrl+C to quit): " text
  [[ -z "$text" ]] && break
  prepended_text="tldr $text"
  
  # Escape spaces in user input for proper command execution
  escaped_text="${text// /\\ }"
  command="tldr $escaped_text"
  
  # Execute the prepended command
  eval "$command"
done
