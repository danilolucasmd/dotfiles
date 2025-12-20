#!/bin/bash

if pactl get-source-mute @DEFAULT_SOURCE@ | grep -q "yes"; then
  echo '{"text":"󰍭","class":"muted"}'
else
  echo '{"text":"󰍬"}'
fi
