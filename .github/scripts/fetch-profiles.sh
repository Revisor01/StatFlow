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
# Erwartet: ASC_KEY_ID, ASC_ISSUER_ID und den .p8 unter
# ~/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8
set -euo pipefail

PROFILE_NAMEN=("StatFlow AppStore 2026" "StatFlow Widget AppStore 2026")
KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
ZIEL="$HOME/Library/MobileDevice/Provisioning Profiles"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

make_jwt() {
  local now exp header payload signing_input sig
  now=$(date +%s); exp=$((now + 1200))
  header=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$ASC_KEY_ID" | b64url)
  payload=$(printf '{"iss":"%s","iat":%d,"exp":%d,"aud":"appstoreconnect-v1"}' \
    "$ASC_ISSUER_ID" "$now" "$exp" | b64url)
  signing_input="${header}.${payload}"
  # ES256 = ECDSA-P256-SHA256; openssl liefert DER, Apple erwartet rohes r||s.
  sig=$(printf '%s' "$signing_input" \
    | openssl dgst -sha256 -sign "$KEY_PATH" \
    | python3 -c '
import sys
der = sys.stdin.buffer.read()
assert der[0] == 0x30
i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7f)
assert der[i] == 0x02
rlen = der[i+1]; r = der[i+2:i+2+rlen]
j = i+2+rlen
assert der[j] == 0x02
slen = der[j+1]; s = der[j+2:j+2+slen]
sys.stdout.buffer.write(r.lstrip(b"\x00").rjust(32, b"\x00") + s.lstrip(b"\x00").rjust(32, b"\x00"))' \
    | b64url)
  printf '%s.%s' "$signing_input" "$sig"
}

mkdir -p "$ZIEL"
JWT=$(make_jwt)

for NAME in "${PROFILE_NAMEN[@]}"; do
  ENC=$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$NAME")
  RESP=$(curl -fsS -m 30 -H "Authorization: Bearer $JWT" \
    "https://api.appstoreconnect.apple.com/v1/profiles?limit=50&filter%5Bname%5D=${ENC}&fields%5Bprofiles%5D=name,uuid,profileContent,profileState")

  echo "$RESP" | ZIEL="$ZIEL" NAME="$NAME" python3 -c '
import base64, json, os, sys
d = json.load(sys.stdin)
name = os.environ["NAME"]
aktiv = [p for p in d.get("data", []) if p["attributes"].get("profileState") == "ACTIVE"]
if not aktiv:
    sys.exit("FEHLER: Profil %r nicht gefunden oder nicht aktiv" % name)
a = aktiv[0]["attributes"]
pfad = os.path.join(os.environ["ZIEL"], a["uuid"] + ".mobileprovision")
with open(pfad, "wb") as f:
    f.write(base64.b64decode(a["profileContent"]))
print("  %s -> %s" % (name, a["uuid"]))'
done
