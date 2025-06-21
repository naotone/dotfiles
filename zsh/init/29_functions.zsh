function gcauto() {
  git commit -m "$(claude -p "Look at the staged git changes and create a summarizing git commit title. Only respond with the title and no affirmation.")"
}

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
  convert $1 -resize 800x800 -quality 90 -flatten -background white -transparent white  -profile '/Library/Application Support/Adobe/Color/Profiles/Recommended/JapanColor2001Coated.icc' -colorspace CMYK  -profile '/Library/Application Support/Adobe/Color/Profiles/Recommended/sRGB Color Space Profile.icm' -colorspace sRGB $1.jpg
}


function sketchPdf() {
 rm -rf ./Exports/_*.pdf && /Applications/Sketch.app/Contents/Resources/sketchtool/bin/sketchtool export artboards --format=pdf --output=./Exports/ $1 && \cpdf out.pdf 300 RGB printer false ./Exports/_*.pdf &&
}

function sketchPdfWatch() {
  chokidar  $1 -c "source ~/.zshrc && rm -rf ./Exports/_*.pdf && sketchtool export artboards --format=pdf --output=./Exports/ $1 && convert ./Exports/_*.pdf ./Exports/all.pdf && \cpdf ./Exports/all.pdf ./Exports/all.min.pdf && rm -rf _*.pdf"
}

function gi() { curl -L -s https://www.gitignore.io/api/$@ ;}
