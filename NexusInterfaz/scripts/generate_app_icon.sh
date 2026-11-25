#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
catalog="NexusInterfaz/Assets.xcassets/AppIcon.appiconset"
source="NexusInterfaz/Assets.xcassets/FullBlue.imageset/art.png"
test -s "$source"
mkdir -p "$catalog"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# Reuse the existing wolf emblem at the top left of the original blue menu.
/usr/bin/sips --cropToHeightWidth 120 120 --cropOffset 0 0 "$source" --out "$tmp/crop.png"
/usr/bin/sips -s format jpeg -s formatOptions best "$tmp/crop.png" --out "$tmp/opaque.jpg"
/usr/bin/sips -s format png --resampleHeightWidth 1024 1024 "$tmp/opaque.jpg" --out "$catalog/AppIcon.png"
test -s "$catalog/AppIcon.png"
/usr/bin/sips -g pixelWidth -g pixelHeight -g hasAlpha "$catalog/AppIcon.png"
