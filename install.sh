#!/bin/bash

set -e
echo "Installing Mac Agent..."

# Install Xcode Command Line Tools if not present
if ! swiftc --version &>/dev/null; then
  echo "Installing Xcode Command Line Tools..."
  sudo xcode-select --install 2>/dev/null || true
  echo "If a dialog appears, click Install. Waiting for installation..."
  until swiftc --version &>/dev/null; do
    sleep 10
  done
  echo "✅ Xcode Command Line Tools installed"
fi

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -d "/opt/homebrew" ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/usr/local/bin/brew shellenv)"
  fi
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

# Download files
echo "Downloading agent files..."
curl -fsSL https://raw.githubusercontent.com/khubaib-6789/mac-contact-creation/main/agent.js -o agent.js
curl -fsSL https://raw.githubusercontent.com/khubaib-6789/mac-contact-creation/main/package.json -o package.json
curl -fsSL https://raw.githubusercontent.com/khubaib-6789/mac-contact-creation/main/add-contact.swift -o add-contact.swift

# Install dependencies
npm install

# Compile Swift binary
echo "Compiling Swift binary..."
swiftc add-contact.swift -o add-contact

# Get paths
CURRENT_USER=$(whoami)
AGENT_PATH=$(pwd)
NODE_PATH=$(which node)

# Allow this user to sudo without password for the binary (so agent can run as other users)
echo "${CURRENT_USER} ALL=(ALL) NOPASSWD: ${AGENT_PATH}/add-contact" | sudo tee /etc/sudoers.d/mac-agent > /dev/null

# Remove any old LaunchDaemon if present
sudo launchctl unload /Library/LaunchDaemons/com.macagent.plist 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/com.macagent.plist

# Create LaunchAgent (runs in user's GUI session — required for Contacts/TCC access)
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

# Load WITHOUT sudo (critical — keeps it in user GUI session for TCC/Contacts access)
launchctl unload ~/Library/LaunchAgents/com.macagent.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.macagent.plist

echo ""
echo "✅ Mac Agent installed and running on port 1299"
echo "✅ Will auto-start when this user logs in"
echo ""
echo "⚠️  IMPORTANT after every reboot:"
echo "    Log into each user once via Fast User Switching"
echo "    so their Contacts session stays active in background."
echo ""
echo "⚠️  First API call will trigger a Contacts permission dialog."
echo "    Click 'OK' to allow."

echo ""
echo "Triggering Contacts permission dialog..."
echo "⚠️  A permission dialog will appear — click 'OK' to allow."
${AGENT_PATH}/add-contact "Permission" "Setup" "+10000000000" "" || true