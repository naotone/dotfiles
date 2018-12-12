binaries=(
  reattach-to-user-namespace
  curl
  docker
  ffmpeg
  git
  jq
  nvm
  rbenv
  pyenv
  the_silver_searcher
  wget
  youtube-dl
)

coreApps=(
  1password
  dropbox
  karabiner-elements
  alfred
  bettertouchtool
  divvy
  notion
  slack
  bartender
  rightfont
  now
  sketch
  visual-studio-code
  encryptme
  choosy
  spotify
)

apps=(
  adobe-creative-cloud
  airtable
  coderunner
  contexts
  craftmanager
  dash
  expressvpn
  flume
  iconjar
  iterm2
  paw
  sequel-pro
  the-clock
  tower2
)

browsers=(
  firefox
  firefox-developer-edition
  google-chrome
  google-chrome-canary
  opera
  safari-technology-preview
  brave
  tor-browser
)

xcode-select --install
sudo xcodebuild -license

echo "Installing homebrew..."
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew update
brew upgrade

echo "installing binaries..."
brew install ${binaries[@]}

echo "installing core apps..."
brew tap homebrew/cask-versions
brew cask install ${coreApps[@]}
brew cask alfred link

echo "installing apps..."
brew cask install ${apps[@]}

echo "installing browsers..."
brew cask install ${browsers[@]}
