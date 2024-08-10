# prepend_tldr.sh

`prepend_tldr.sh` is a simple Bash script that allows you to prepend the `tldr` command to any command you enter, giving you quick access to simplified command-line documentation.

## Usage

This script prompts the user to enter a command, then prepends `tldr` to the command and executes it. The `tldr` tool provides concise examples for common command-line usage, which is helpful for users who need a quick reminder of how to use a particular command.

### Running the Script

1. Make sure you have `tldr` installed on your system. If not, you can install it using your package manager. For example:
   - On Debian/Ubuntu: `sudo apt-get install tldr`
   - On Arch Linux: `sudo pacman -S tldr`
   - On macOS: `brew install tldr`

2. Download or clone the script to your local machine.

3. Make the script executable:

   ```bash
   chmod +x prepend_tldr.sh
   ```

4. Run the script:

   ```bash
   ./prepend_tldr.sh
   ```

### Example

```bash
Enter your command (or Ctrl+C to quit): ls
```

This input will be processed as:

```bash
tldr ls
```

And the script will display the `tldr` page for the `ls` command.

### Exiting the Script

- Press `Ctrl+C` to quit the script at any time.
- If you enter an empty command, the script will terminate automatically.

## Script Details

### Source Code

```bash
#!/bin/bash

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
```

### How It Works

- The script enters an infinite loop, prompting the user to enter a command.
- If the user enters a command, it prepends `tldr` to the command.
- The script handles spaces in the input by escaping them for proper execution.
- The `tldr` command is then executed using `eval`.
- If the user enters an empty command or uses `Ctrl+C`, the script exits.

## License

This script is open-source and available under the GNU General Public License v3.0.
