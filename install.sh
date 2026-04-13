#!/bin/bash

echo "Installing Mac Agent..."

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install Node if not present
if ! command -v node &> /dev/null; then
  echo "Installing Node.js..."
  brew install node
fi

# Ask for API key
read -p "Enter your API key: " API_KEY

# Create agent folder
mkdir -p ~/mac-agent
cd ~/mac-agent

# Download agent files
curl -fsSL https://raw.githubusercontent.com/khubaib-6789/mac-contact-creation/main/agent.js -o agent.js
curl -fsSL https://raw.githubusercontent.com/khubaib-6789/mac-contact-creation/main/package.json -o package.json

# Install dependencies
npm install

# Get current user and paths
CURRENT_USER=$(whoami)
AGENT_PATH=$(pwd)
NODE_PATH=$(which node)

# Create launchd plist
sudo tee /Library/LaunchDaemons/com.macagent.plist > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.macagent</string>
    <key>ProgramArguments</key>
    <array>
        <string>${NODE_PATH}</string>
        <string>${AGENT_PATH}/agent.js</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>API_KEY</key>
        <string>${API_KEY}</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/mac-agent.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/mac-agent-error.log</string>
</dict>
</plist>
EOF

# Set sudoers permission
echo "${CURRENT_USER} ALL=(ALL) NOPASSWD: /usr/bin/osascript" | sudo tee /etc/sudoers.d/mac-agent > /dev/null

# Load the agent
sudo launchctl load /Library/LaunchDaemons/com.macagent.plist

echo ""
echo "✅ Mac Agent installed and running on port 1299"
echo "✅ Will auto-start on every reboot"