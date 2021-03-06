brew=(
  reattach-to-user-namespace
  fabianishere/personal/pam_reattach
  kryptco/tap/kr
  nvm
  curl
  docker
  ffmpeg
  git
  jq
  rbenv
  pyenv
  the_silver_searcher
  wget
  youtube-dl
)

cask=(
  1password
  dropbox
  karabiner-elements
  alfred
  bettertouchtool
  divvy
  bartender
  rightfont
  figma
  sketch
  visual-studio-code
  encryptme
  choosy
  spotify
  notion
  slack
)

cask2=(
  station
  adobe-creative-cloud
  airtable
  coderunner
  contexts
  dash
  expressvpn
  flume
  iconjar
  paw
  sequel-pro
  the-clock
  tower
)

browsers=(
  firefox
  firefox-developer-edition
  google-chrome
  google-chrome-canary
  opera
  safari-technology-preview
  brave-browser
  microsoft-edge
  tor-browser
)

xcode-select --install
sudo xcodebuild -license

echo "Installing homebrew..."
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew update
brew upgrade

echo "installing packages..."
brew install ${brew[@]}

echo "installing primary apps..."
brew tap homebrew/cask-versions
brew cask install ${cask[@]}
brew cask alfred link

echo "installing apps..."
brew cask install ${cask2[@]}

echo "installing browsers..."
brew cask install ${browsers[@]}
