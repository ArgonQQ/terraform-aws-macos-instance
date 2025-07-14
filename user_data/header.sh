#!/bin/bash
# Log file setup
LOG_FILE="/var/log/instance-init.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "macOS instance initialization started at $(date)"

# Accept Xcode license if needed
# sudo xcodebuild -license accept
