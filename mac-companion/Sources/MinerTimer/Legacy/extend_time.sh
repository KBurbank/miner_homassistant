#!/bin/zsh
read -s "password?Enter password for additional time: "
echo "$password" > /tmp/minertimer_extension_attempt
echo "\nPassword submitted. Please wait for verification." 