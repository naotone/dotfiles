brew=(
  tmux
  reattach-to-user-namespace
  fabianishere/personal/pam_reattach
  coreutils
  fzf
  ghostty
  hammerspoon
  raycast
  1password
  contexts
  keyboardcleantool
  font-sf-pro
  font-sf-mono
  tailscale-app
  rapidapi
  nordvpn
  ngrok
  tripmode
  cursor
  visual-studio-code
  appcleaner
  adobe-creative-cloud
  slack
  notion
  discord
  figma
)

browsers=(
  google-chrome
  google-chrome@canary
  safari-technology-preview
  firefox
  firefox@developer-edition
  brave-browser
  opera
  microsoft-edge
  tor-browser
)

xcode-select --install
sudo xcodebuild -license

echo "Installing homebrew..."
if ! command -v brew &> /dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
brew update
brew upgrade

echo "installing packages..."
brew install ${brew[@]}

echo "installing browsers..."
brew install --cask ${browsers[@]}
