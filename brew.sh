brew=(
  reattach-to-user-namespace
  fabianishere/personal/pam_reattach
  # kryptco/tap/kr Cannot install with brew. curl https://krypt.co/kr | sed "s/11.0/12.0/g" | sh
  nvm
  curl
  # docker
  ffmpeg
  git
  jq
  rbenv
  pyenv
  the_silver_searcher
  wget
  yarn
  youtube-dl
)

cask=(
  1password
  alfred
  # bettertouchtool
  choosy
  divvy
  bartender
  figma
  hammerspoon
  visual-studio-code
  notion
  slack
)

cask2=(
  adobe-creative-cloud
  airtable
  cleanshot
  coderunner
  contexts
  dash
  deepl
  dropbox
  expressvpn
  grammarly
  gray
  iconjar
  numi
  paw
  rightfont
  sip
  sketch
  spotify
  # sequel-pro
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

#xcode-select --install
#sudo xcodebuild -license

# echo "Installing homebrew..."
# /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
# brew update
# brew upgrade

#echo "installing packages..."
#brew install ${brew[@]}

#echo "installing primary apps..."
#brew tap homebrew/cask-versions
#brew install --cask ${cask[@]}
#brew link alfred
#
#echo "installing apps..."
#brew install --cask ${cask2[@]}

echo "installing browsers..."
brew install --cask ${browsers[@]}
