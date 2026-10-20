#!/usr/bin/env bash
# Print the Mac's LAN IP to paste into client/src/config/game_config.gd.
ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
echo "SERVER_HOST := \"$ip\""
echo "Full URL: ws://$ip:8080"
