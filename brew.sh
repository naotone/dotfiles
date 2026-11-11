brew=(
  tmux
  reattach-to-user-namespace
  pam-reattach
  coreutils
  rsync
  speedtest-go
  git
  hunk
  gh
  fzf
  ghostty
  cursor
  hammerspoon
  raycast
  tailscale
  mise
  1password
  1password-cli
  contexts
  chatgpt
  grok-bot
  cleanshot
  font-sf-pro
  font-sf-mono
  orbstack
  nordvpn
  tripmode
  rapidapi
  appcleaner
  slack
  notion
  discord
  dropbox
  figma
  figma@beta
  hf
  ollama
  ollama-app
  lm-studio
  ariga/tap/atlas
  adobe-creative-cloud
  linear-linear
  visual-studio-code
  proxyman
  tableplus
  zoom
  font-geist
  font-geist-mono
)

browsers=(
  choosy
  zen
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
brew upgrade --yes

echo "installing packages..."
brew install --yes ${brew[@]}

echo "installing browsers..."
brew install --yes --cask ${browsers[@]}
