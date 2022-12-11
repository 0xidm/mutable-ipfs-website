#!/bin/bash

STYLE=$1
if [ -z "$STYLE" ]; then
  echo "Usage: $0 <style>"
  exit 1
fi

mkdir -p _site _build

echo "copy template.html and index.md"
cp styles/template.html _build
cp index.md _build

echo "render index.html"
pushd _build || exit 1
pandoc \
    -f markdown -t html \
    --self-contained \
    --template template.html \
    -o index.raw.html \
    index.md
popd || exit 1

echo "insert timestamp"
sed -i .bak -e "s/RENDER_TIMESTAMP/$(date -u)/g" _build/index.raw.html

echo "copy html to _site"
cp _build/index.raw.html _site/index.html

echo "done; file is available in _site/index.html"
