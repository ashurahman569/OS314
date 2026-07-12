#!/usr/bin/bash

: '
The LED blinking will not work in WSL/VM as it does not have access to the hardware.
Only native Linux systems will be able to run this script successfully.
If you keyboard does not have a functional Caps Lock LED,
you can modify the script to use a different LED (numlock, scroll lock, etc.).

First grant execute permission to the script:
chmod +x solution_B1.sh

Then run the script:
sudo ./solution_B1.sh
'

# Change the LED_PATH based on your system
# Only the numeric part may vary, the rest should be the same
# For example: /sys/class/leds/input6::capslock/brightness
LED_PATH="/sys/class/leds/input24::capslock/brightness"

blink_led() {
  for i in {1..5}; do
    echo 1 >"$LED_PATH"
    sleep 0.1
    echo 0 >"$LED_PATH"
    sleep 0.1
  done
}

while true; do
  # Prompt the user for a command
  echo -n "Enter a command: "
  read user_command

  # If the user enters 'exit', break the loop and quit
  if [[ "$user_command" == "exit" ]]; then
    echo "Exiting command monitor."
    break
  fi

  # Run the user's command and capture the exit status
  eval "$user_command"
  status=$?

  # Check the exit status of the command
  if [[ $status -eq 0 ]]; then
    echo "Success: Command executed successfully."
  else
    echo "Failed: Command exited with status $status."
    blink_led
  fi
done
