#!/usr/bin/env bash
# Laedt die Provisioning-Profile fuer App und Widget aus App Store Connect
# und legt sie dort ab, wo xcodebuild sie erwartet.
#
# Warum ueberhaupt: Der Runner ist jedes Mal eine frische Maschine ohne
# Zertifikat im Schluesselbund. Mit `-allowProvisioningUpdates` legte Xcode
# deshalb bei JEDEM Lauf ein neues Development-Zertifikat an. Apple erlaubt
# davon zwei je Konto, danach scheitert der Build mit "Choose a certificate
# to revoke" — passiert am 18.09.2026 nach acht Builds an einem Tag.
#
# Welches Profil welches Ziel signiert, steht pro Target in der
# project.pbxproj (PROVISIONING_PROFILE_SPECIFIER). Global gesetzt bekaeme
# auch das Widget das App-Profil und der Build braeche ab.
#
# Erwartet: ASC_KEY_ID, ASC_ISSUER_ID und den .p8 unter
# ~/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8
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
# Release steht. Profile und Distribution-Zertifikat enden am 28.11.2026.
rest = (datetime.fromisoformat(a["expirationDate"]) - datetime.now(timezone.utc)).days
hinweis = "  ACHTUNG: laeuft in %d Tagen ab" % rest if rest < 30 else ""
print("  %s -> %s (noch %d Tage)%s" % (name, a["uuid"], rest, hinweis))'
done
