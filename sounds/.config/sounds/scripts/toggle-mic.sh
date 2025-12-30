#!/bin/bash

# Toggle mic (same command you already use)
pactl set-source-mute @DEFAULT_SOURCE@ toggle

# Play sound based on new state
if pactl get-source-mute @DEFAULT_SOURCE@ | grep -q "yes"; then
  paplay ~/.config/sounds/mic-off.mp3
else
  paplay ~/.config/sounds/mic-on.mp3
fi
