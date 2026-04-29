#!/bin/bash

echo "Installing Mac Agent..."

# Install Xcode Command Line Tools if not present
if ! swiftc --version &>/dev/null 2>&1 || ! /usr/bin/swiftc --version 2>&1 | grep -q "Swift version"; then
  echo "Installing Xcode Command Line Tools..."
  sudo xcode-select --install
  echo "Click Install on the dialog. Waiting for installation to complete..."
  until swiftc --version &>/dev/null; do
    sleep 10
  done
  echo "✅ Xcode Command Line Tools installed"
fi

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo >> /Users/$(whoami)/.zprofile
  echo 'eval "$(/opt/homebrew/bin/brew shellenv zsh)"' >> /Users/$(whoami)/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
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
curl -fsSL https://raw.githubusercontent.com/khubaib-6789/mac-contact-creation/main/add-contact.swift -o add-contact.swift

# Install dependencies
npm install

# Compile Swift binary
echo "Compiling Swift binary..."
swiftc add-contact.swift -o add-contact

# Get paths
AGENT_PATH=$(pwd)
NODE_PATH=$(which node)

echo "Using node at: $NODE_PATH"

# Create LaunchAgent (runs in user's GUI session - critical for TCC/Contacts access)
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/com.macagent.plist <<EOF
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
    <string>/tmp/mac-agent.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/mac-agent-error.log</string>
</dict>
</plist>
EOF

# Load WITHOUT sudo (keeps it in user GUI session for Contacts/TCC access)
launchctl unload ~/Library/LaunchAgents/com.macagent.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.macagent.plist

echo ""
echo "✅ Mac Agent installed and running on port 1299"
echo "✅ Will auto-start when this user logs in"
echo ""
echo "⚠️  IMPORTANT: Make sure to log into each user once via Fast User Switching"
echo "    after every reboot for their agent to run."