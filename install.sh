#!/bin/bash

echo "Installing Mac Agent..."

# Install Xcode Command Line Tools headlessly if not present
if ! swiftc --version &>/dev/null 2>&1 || ! /usr/bin/swiftc --version 2>&1 | grep -q "Swift version"; then
  echo "Installing Xcode Command Line Tools (this takes a few minutes)..."
  
  # Trick to make softwareupdate see CLT as available
  sudo touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  
  # Find the latest CLT package and install it
  CLT_PACKAGE=$(softwareupdate -l 2>&1 | grep -B 1 "Command Line Tools" | awk -F'*' '/^ *\*/ {print $2}' | sed -e 's/^ *Label: //' -e 's/^ *//' | sort -V | tail -n1)
  
  if [ -n "$CLT_PACKAGE" ]; then
    sudo softwareupdate -i "$CLT_PACKAGE" --verbose
  else
    echo "Could not find Command Line Tools package automatically"
    sudo softwareupdate -i -a --verbose
  fi
  
  sudo rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  
  # Verify
  if ! swiftc --version &>/dev/null; then
    echo "❌ Failed to install Xcode Command Line Tools"
    exit 1
  fi
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

# Pre-compile the Swift binary
echo "Compiling Swift binary..."
swiftc add-contact.swift -o add-contact

# Get current user and paths
CURRENT_USER=$(whoami)
AGENT_PATH=$(pwd)
NODE_PATH=$(which node)

echo "Using node at: $NODE_PATH"

# Create launchd plist
sudo tee /Library/LaunchDaemons/com.macagent.plist > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.macagent</string>
    <key>UserName</key>
    <string>${CURRENT_USER}</string>
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
echo "${CURRENT_USER} ALL=(ALL) NOPASSWD: /usr/bin/osascript, ${AGENT_PATH}/add-contact" | sudo tee /etc/sudoers.d/mac-agent > /dev/null

# Load the agent
sudo launchctl unload /Library/LaunchDaemons/com.macagent.plist 2>/dev/null
sudo launchctl load /Library/LaunchDaemons/com.macagent.plist

echo ""
echo "✅ Mac Agent installed and running on port 1299"
echo "✅ Will auto-start on every reboot"