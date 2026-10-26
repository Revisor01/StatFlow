#!/bin/bash
# Xcode Cloud, nach dem Klonen: Signieren auf automatisch stellen und die
# Build-Nummer pruefen. Der Release auf GitHub signiert fest mit eigenen
# Profilen, die es in der Cloud nicht gibt; umgestellt wird nur der Klon.
set -euo pipefail

REPO="${CI_PRIMARY_REPOSITORY_PATH:?Nur fuer Xcode Cloud gedacht.}"
PBXPROJ="$REPO/InsightFlow.xcodeproj/project.pbxproj"

# Xcode Cloud ersetzt die Build-Nummer durch die eigene. Liegt sie nicht ueber
# der im Projekt, lehnt App Store Connect den Upload erst nach dem Build ab.
PROJEKT_NUMMER=$(grep -m1 -oE 'CURRENT_PROJECT_VERSION = [0-9]+' "$PBXPROJ" | grep -oE '[0-9]+$')
if [ "${CI_BUILD_NUMBER:?}" -le "$PROJEKT_NUMMER" ]; then
  echo "FEHLER: Xcode-Cloud-Build $CI_BUILD_NUMBER liegt nicht ueber $PROJEKT_NUMMER aus dem Projekt. In App Store Connect unter Xcode Cloud > Settings > Build Number die naechste Nummer hoeher setzen."
  exit 1
fi

for zeile in 'CODE_SIGN_STYLE = Manual;' 'CODE_SIGN_IDENTITY = "Apple Distribution";'; do
  [ "$(grep -cF "$zeile" "$PBXPROJ")" = 2 ] || { echo "FEHLER: '$zeile' steht nicht genau zweimal in project.pbxproj."; exit 1; }
done
for profil in 'StatFlow AppStore 2026' 'StatFlow Widget AppStore 2026'; do
  [ "$(grep -cF "PROVISIONING_PROFILE_SPECIFIER = \"$profil\";" "$PBXPROJ")" = 1 ] || { echo "FEHLER: Profil '$profil' steht nicht genau einmal in project.pbxproj."; exit 1; }
done
sed -i.vorher \
  -e 's/CODE_SIGN_STYLE = Manual;/CODE_SIGN_STYLE = Automatic;/' \
  -e 's/CODE_SIGN_IDENTITY = "Apple Distribution";/CODE_SIGN_IDENTITY = "Apple Development";/' \
  -e 's/PROVISIONING_PROFILE_SPECIFIER = "StatFlow \(Widget \)\{0,1\}AppStore 2026";/PROVISIONING_PROFILE_SPECIFIER = "";/' \
  "$PBXPROJ"
rm "$PBXPROJ.vorher"
echo "Signieren fuer Xcode Cloud auf automatisch gestellt, Build $CI_BUILD_NUMBER."
