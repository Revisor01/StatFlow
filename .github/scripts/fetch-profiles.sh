#!/usr/bin/env bash
# Laedt die Provisioning-Profile fuer App und Widget aus App Store Connect und
# legt sie ab, wo xcodebuild sie erwartet. Ohne fertige Profile legt Xcode auf
# dem frischen Runner bei jedem Lauf ein Development-Zertifikat an; nach zwei
# davon scheitert der Build. Erwartet ASC_KEY_ID, ASC_ISSUER_ID und den .p8
# unter ~/.appstoreconnect/private_keys/.
set -euo pipefail

source "$(dirname "$0")/asc-jwt.sh"

PROFILE_NAMEN=("StatFlow AppStore 2026" "StatFlow Widget AppStore 2026")
ZIEL="$HOME/Library/MobileDevice/Provisioning Profiles"

mkdir -p "$ZIEL"

for NAME in "${PROFILE_NAMEN[@]}"; do
  ENC=$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$NAME")
  RESP=$(asc_get "/v1/profiles?limit=50&filter%5Bname%5D=${ENC}&fields%5Bprofiles%5D=name,uuid,profileContent,profileState,expirationDate")

  echo "$RESP" | ZIEL="$ZIEL" NAME="$NAME" python3 -c '
import base64, json, os, sys
from datetime import datetime, timezone
d = json.load(sys.stdin)
name = os.environ["NAME"]
aktiv = [p for p in d.get("data", []) if p["attributes"].get("profileState") == "ACTIVE"]
if not aktiv:
    sys.exit("FEHLER: Profil %r nicht gefunden oder nicht aktiv" % name)
a = aktiv[0]["attributes"]
pfad = os.path.join(os.environ["ZIEL"], a["uuid"] + ".mobileprovision")
with open(pfad, "wb") as f:
    f.write(base64.b64decode(a["profileContent"]))
# Laeuft das Profil bald ab, faellt das hier auf und nicht erst, wenn der
# Release steht.
rest = (datetime.fromisoformat(a["expirationDate"]) - datetime.now(timezone.utc)).days
hinweis = "  ACHTUNG: laeuft in %d Tagen ab" % rest if rest < 30 else ""
print("  %s -> %s (noch %d Tage)%s" % (name, a["uuid"], rest, hinweis))'
done
