# cmd_history() {
#     if has fzy; then
#         local tac
#         if which tac > /dev/null; then
#             tac="tac"
#         else
#             tac="tail -r"
#         fi
#         BUFFER=$(fc -l -n 1 | eval $tac | fzy)
#         CURSOR=${#BUFFER}
#     fi
# }
# zle -N cmd_history

function peco-select-history() {
    local tac
    if which tac > /dev/null; then
        tac="tac"
    else
        tac="tail -r"
    fi
    BUFFER=$(history -n 1 | \
        eval $tac | \
        peco --query "$LBUFFER")
    CURSOR=$#BUFFER
    zle clear-screen
}

if (( ${+commands[peco]} )); then
  peco-go-to-dir () {
    local line
    local selected="$(
      {
        (
          autoload -Uz chpwd_recent_filehandler
          chpwd_recent_filehandler && for line in $reply; do
            if [[ -d "$line" ]]; then
              echo "$line"
            fi
          done
        )
        ghq list --full-path
        for line in *(-/) ${^cdpath}/*(N-/); do echo "$line"; done | sort -u
      } | peco --query "$LBUFFER"
    )"
    if [ -n "$selected" ]; then
      BUFFER="cd ${(q)selected}"
      zle accept-line
    fi
    zle clear-screen
  }
fi

function peco-cdr () {
    local selected_dir="$(cdr -l | awk '{ print $2 }' | peco)"
    if [ -n "$selected_dir" ]; then
        BUFFER="cd ${(q)selected_dir}"
        zle accept-line
    fi
    zle clear-screen
}

function peco-select-gitadd() {
    local SELECTED_FILE_TO_ADD="$(git status --porcelain | \
                                  peco --query "$LBUFFER" | \
                                  awk -F ' ' '{print $NF}')"
    if [ -n "$SELECTED_FILE_TO_ADD" ]; then
      BUFFER="git add $(echo "$SELECTED_FILE_TO_ADD" | tr '\n' ' ')"
      CURSOR=$#BUFFER
    fi
    zle accept-line
    # zle clear-screen
}

# Usage: cpdf $1[output file] $2[dpi] $3[Gray|CMYK|RGB*] $4[screen|ebook|printer*|prepress|default] $5[Transparency] $6[input file]
function cpdf() {
   \gs -sOutputFile=${1:-"output.min.pdf"} -sDEVICE=pdfwrite \
      -dNOPAUSE -dBATCH -dSAFER -dHaveTransparency=${5:-false} \
      -dCompatibilityLevel=1.4 -dPDFSETTINGS=/${4:-"printer"} \
      -dEmbedAllFonts=true -dSubsetFonts=true \
      -sColorConversionStrategy=/${3:-"RGB"} -dProcessColorModel=/Device${3:-"RGB"} \
      -dGrayImageDownsampleType=/Bicubic -dGrayImageResolution=${2:-"200"} \
      -dMonoImageDownsampleType=/Bicubic -dMonoImageResolution=${2:-"200"} \
      -dColorImageDownsampleType=/Bicubic -dColorImageResolution=${2:-"200"} \
      ${@:6:($#-5)} < /dev/null
}

function generateTnumbnail() {
  convert $1 -resize 800x800 -quality 90  -background white -flatten -transparent white  -profile '/Library/Application Support/Adobe/Color/Profiles/Recommended/JapanColor2001Coated.icc' -colorspace CMYK  -profile '/Library/Application Support/Adobe/Color/Profiles/Recommended/sRGB Color Space Profile.icm' -colorspace sRGB $1.jpg
}

function sketchPdf() {
 rm -rf ./Exports/_*.pdf && /Applications/Sketch.app/Contents/Resources/sketchtool/bin/sketchtool export artboards --format=pdf --output=./Exports/ $1 && \cpdf out.pdf 300 RGB printer false ./Exports/_*.pdf && rm -rf ./Exports/_*.pdf
}

function sketchPdfWatch() {
  chokidar  $1 -c "source ~/.zshrc && rm -rf ./Exports/_*.pdf && sketchtool export artboards --format=pdf --output=./Exports/ $1 && convert ./Exports/_*.pdf ./Exports/all.pdf && \cpdf ./Exports/all.pdf ./Exports/all.min.pdf && rm -rf _*.pdf"
}

function gi() { curl -L -s https://www.gitignore.io/api/$@ ;}
