#!/bin/bash

if pgrep -x "wf-recorder" >/dev/null; then
  echo '{"text":"","class":"recording","tooltip":"Recording"}'
else
  echo '{"text":""}'
fi
