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


# gtac: brew install coreutils / brew install fzf
function fzf-select-history() {
  local cmd
  cmd=$(awk '
    BEGIN { cmd = ""; firstLine = ""; }
    /^: [0-9]{10,}:[01];/ {
      if (cmd != "") {
        if (firstLine == "") {
          firstLine = $0;
        }
        print cmd "\t" firstLine;
        cmd = "";
        firstLine = "";
      }
      firstLine = $0;
      cmd = substr($0, index($0, ";") + 1);
    }
    !/^: [0-9]{10,}:[01];/ {
      cmd = cmd "\\n" $0;
    }
    END {
      if (cmd != "") print cmd "\t" firstLine;
    }
  ' "$HISTFILE" |
    tac | awk -F"\t" '!seen[$1]++ && $2 != "" {print $0}' |
    fzf --query "$LBUFFER" --reverse --multi --delimiter="\t" --with-nth=1 \
        --preview "echo -e \"\033[90mCommand\033[0m\";
                   echo {1};
                   echo \"\";
                   echo -e \"\033[90mWrapped\033[0m\";
                   echo {1} | sed 's/\\\\n/\n/g' | fold -s -w 120;
                  #  echo \"\";
                  #  echo -e \"\033[Fist Line\033[0m\";
                  #  echo {2};
                   " \
        --bind "ctrl-x:execute(
            # Debug info
            # echo \"=== Deleting entry ===\" > /tmp/fzf_history_debug.log
            # echo \"Command: {1}\" >> /tmp/fzf_history_debug.log
            # echo \"First Line: {2}\" >> /tmp/fzf_history_debug.log
            # echo \"=== Before deletion ===\" >> /tmp/fzf_history_debug.log
            # head -n 10 \"$HISTFILE\" >> /tmp/fzf_history_debug.log

            timestamp=$(date +%Y%m%d%H%M%S)
            tmpfile=\"/tmp/zsh_history.\$timestamp.tmp\"

            (awk -v target="{2}" '
              BEGIN {
                # print \"Target for deletion:  \"target >> \"/tmp/fzf_history_debug.log\"
                skip = 0;
              }
              /^: [0-9]{10,}:[01];/ {
                # print \"First Line: \"\$0 >> \"/tmp/fzf_history_debug.log\"
                # if (index(\$0, target) != 0) {
                if (\$0 == target){
                  # print \"Unmatched for deletion: \" \$0 >> \"/tmp/fzf_history_debug.log\"
                  skip = 1;
                } else {
                  # print \"Matched for deletion: \" \$0 >> \"/tmp/fzf_history_debug.log\"
                  skip = 0;
                  print;
                }
              }
              !/^: [0-9]{10,}:[01];/ {
                # print \"Deleting line: \"\$0 >> \"/tmp/fzf_history_debug.log\"
                if (!skip) print;
              }
            ' $HISTFILE > \$tmpfile && cp \$tmpfile $HISTFILE)

            # echo \"=== After deletion ===\" >> /tmp/fzf_history_debug.log
            # head -n 10 \"$HISTFILE\" >> /tmp/fzf_history_debug.log

        )+reload(awk '
          BEGIN { cmd = \"\"; firstLine = \"\"; }
          /^: [0-9]+:[0-9]+;/ {
            if (cmd != \"\") {
              if (firstLine == \"\") {
                firstLine = \$0;
              }
              print cmd \"\\t\" firstLine;
              cmd = \"\";
              firstLine = \"\";
            }
            firstLine = \$0;
            cmd = substr(\$0, index(\$0, \";\") + 1);
          }
          !/^: [0-9]+:[0-9]+;/ {
            cmd = cmd \"\\\\n\" \$0;
            firstLine = firstLine \"\\n\" \$0;
          }
          END {
            if (cmd != \"\") print cmd \"\\t\" firstLine;
          }

        ' $HISTFILE | tac | awk -F\"\\t\" \"!seen[\\\$1]++ && \\\$2 != \\\"\\\" {print \\\$0}\")"\
        --bind "ctrl-q:execute(
            echo {1} | sed 's/\\\\n/\\n/g' | pbcopy
        )" \
  )
  if [[ -n "$cmd" ]]; then
    # Extract just the command part (before the tab)
    cmd=$(echo "$cmd" | cut -f1 | sed 's/\\n/\n/g')
    BUFFER="$cmd"
    CURSOR=$#BUFFER
    zle accept-line
  fi
}
zle -N fzf-select-history

function fzf-cdr() {
    local selected=$(cdr -l | awk '{print $2}' | fzf --reverse)
    if [[ -n "$selected" ]]; then
        BUFFER="cd ${(Q)selected}"
        zle accept-line
    fi
    zle reset-prompt
}
zle -N fzf-cdr

function fzf-go-to-dir() {
    local dir
    dir=$(
        {
        find "${HOME}" -mindepth 1 -maxdepth 5 -type d \( -name "node_modules" -o -name ".git" \) -prune -o -type d -print 2>/dev/null
        find / -mindepth 1 -maxdepth 3 -type d \( -name "node_modules" -o -name ".git" \) -prune -o -type d -print 2>/dev/null
        } | fzf --reverse
    )
    if [[ -n "$dir" ]]; then
        dir="${(Q)dir}"
        dir="${dir/#$HOME/~}"  # $HOME を ~ に変換
        BUFFER="cd $dir"
        zle accept-line
    fi
}
zle -N fzf-go-to-dir

#Peco
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
# function cpdf() {
#    \gs -sOutputFile=${1:-"output.min.pdf"} -sDEVICE=pdfwrite \
#       -dNOPAUSE -dBATCH -dSAFER -dNOCACHE -dHaveTransparency=${5:-false} \
#       -dCompatibilityLevel=1.4 -dPDFSETTINGS=/${4:-"printer"} \
#       -dEmbedAllFonts=true -dSubsetFonts=true \
#       # -sColorConversionStrategy=/${3:-"RGB"} -dProcessColorModel=/Device${3:-"RGB"} \
#       -dGrayImageDownsampleType=/Bicubic -dGrayImageResolution=${2:-"200"} \
#       -dMonoImageDownsampleType=/Bicubic -dMonoImageResolution=${2:-"200"} \
#       -dColorImageDownsampleType=/Bicubic -dColorImageResolution=${2:-"200"} \
#       ${@:6:($#-5)} < /dev/null
# }
function cpdf() {
   \gs -sOutputFile=${1:-"output.min.pdf"} -sDEVICE=pdfwrite \
      -dNOPAUSE -dBATCH -dSAFER -dNOCACHE -dHaveTransparency=${5:-false} \
      -dCompatibilityLevel=1.4 -dPDFSETTINGS=/${4:-"printer"} \
      -dEmbedAllFonts=true -dSubsetFonts=true \
      -dGrayImageDownsampleType=/Bicubic -dGrayImageResolution=${2:-"200"} \
      -dMonoImageDownsampleType=/Bicubic -dMonoImageResolution=${2:-"200"} \
      -dColorImageDownsampleType=/Bicubic -dColorImageResolution=${2:-"200"} \
      ${@:6:($#-5)} < /dev/null
}

function pdfmin(){
  local cnt=0
  for i in $@; do
    \gs -sDEVICE=pdfwrite \
      -dCompatibilityLevel=1.4 \
      -dPDFSETTINGS=/ebook \
      -dNOPAUSE -dBATCH \
      -sOutputFile=${i%%.*}.min.pdf ${i} &
    (( (cnt += 1) % 4 == 0 )) && wait
  done
  wait && return 0
}

function generateThumbnail() {
  convert $1 -resize 800x800 -quality 90 -background white -transparent white  -profile '/Library/Application Support/Adobe/Color/Profiles/Recommended/JapanColor2001Coated.icc' -colorspace CMYK  -profile '/Library/Application Support/Adobe/Color/Profiles/Recommended/sRGB Color Space Profile.icm' -colorspace sRGB $1.jpg
}

function generateThumbnailFlatten() {
  convert $1 -resize 800x800 -quality 90 -flatten -background white -transparent white  -profile '/Library/Application Support/Adobe/Color/Profiles/Recommended/JapanColor2001Coated.icc' -colorspace CMYK  -profile '/Library/Application Support/Adobe/Color/Profiles/Recommended/sRGB Color Space Profile.icm' -colorspace sRGB $1.jpg
}


function sketchPdf() {
 rm -rf ./Exports/_*.pdf && /Applications/Sketch.app/Contents/Resources/sketchtool/bin/sketchtool export artboards --format=pdf --output=./Exports/ $1 && \cpdf out.pdf 300 RGB printer false ./Exports/_*.pdf &&
}

function sketchPdfWatch() {
  chokidar  $1 -c "source ~/.zshrc && rm -rf ./Exports/_*.pdf && sketchtool export artboards --format=pdf --output=./Exports/ $1 && convert ./Exports/_*.pdf ./Exports/all.pdf && \cpdf ./Exports/all.pdf ./Exports/all.min.pdf && rm -rf _*.pdf"
}

function gi() { curl -L -s https://www.gitignore.io/api/$@ ;}
