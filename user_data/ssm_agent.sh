#!/bin/bash
# SSM Agent installation script for macOS
# This script detects the architecture and installs the appropriate SSM agent

# Create temp directory
TEMP_DIR="/tmp/ssm-install"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Detect architecture
ARCH=$(uname -m)
echo "Detected architecture: $ARCH"

if [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
  ARCH_TYPE="arm64"
  echo "Using ARM64 SSM agent package"
elif [[ "$ARCH" == "x86_64" ]]; then
  ARCH_TYPE="amd64"
  echo "Using AMD64 SSM agent package"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# Download the appropriate SSM agent
echo "Downloading SSM agent for macOS ($ARCH_TYPE)"
DOWNLOAD_URL="https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/darwin_$${ARCH_TYPE}/amazon-ssm-agent.pkg"
curl -s -O "$DOWNLOAD_URL"

if [ ! -f "amazon-ssm-agent.pkg" ]; then
  echo "Failed to download SSM agent"
  exit 1
fi

# Install the agent
echo "Installing SSM agent"
installer -pkg amazon-ssm-agent.pkg -target /

# Configure SSM agent to run as specified user
echo "Configuring SSM agent to run as $${ssm_run_as_user}"
mkdir -p /var/lib/amazon/ssm/
cat > /var/lib/amazon/ssm/amazon-ssm-agent.json << SSMCONFIG
{
    "Profile": "default",
    "Mds": {
        "CommandWorkersLimit": 5
    },
    "Ssm": {
        "RunAsEnabled": true,
        "RunAsDefaultUser": "$${ssm_run_as_user}"
    }
}
SSMCONFIG

# Set proper permissions
chmod 644 /var/lib/amazon/ssm/amazon-ssm-agent.json

# Restart the SSM agent
echo "Restarting SSM agent"
launchctl unload /Library/LaunchDaemons/com.amazon.aws.ssm.plist 2>/dev/null || true
launchctl load -w /Library/LaunchDaemons/com.amazon.aws.ssm.plist

# Clean up
cd /
rm -rf "$TEMP_DIR"

echo "SSM agent installation completed"
