brew=(
  tmux
  reattach-to-user-namespace
  fabianishere/personal/pam_reattach
  coreutils
  fzf
  ghostty
  cursor
  hammerspoon
  raycast
  1password
  1password-cli
  docker-desktop
  contexts
  font-sf-pro
  font-sf-mono
  tailscale-app
  nordvpn
  ngrok
  tripmode
  visual-studio-code
  rapidapi
  adobe-creative-cloud
  appcleaner
  keyboardcleantool
  slack
  notion
  discord
  figma
  zoom
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
