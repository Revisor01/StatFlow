#!/usr/bin/env bash
# Baut einen JWT fuer die App-Store-Connect-API und stellt `asc_get` bereit.
# Wird von den anderen Skripten in diesem Ordner eingebunden (`source`), nicht
# selbst aufgerufen.
#
# Bewusst ohne Fremdbibliothek: der Runner soll fuer einen signierten Request
# kein Ruby-Gem und kein pip-Paket nachladen muessen. openssl und python3
# liegen auf jedem macOS-Runner bereit.
#
# Erwartet: ASC_KEY_ID, ASC_ISSUER_ID und den .p8 unter
# ~/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8

ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

asc_jwt() {
  local now exp header payload signing_input sig
  now=$(date +%s); exp=$((now + 1200))
  header=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$ASC_KEY_ID" | b64url)
  payload=$(printf '{"iss":"%s","iat":%d,"exp":%d,"aud":"appstoreconnect-v1"}' \
    "$ASC_ISSUER_ID" "$now" "$exp" | b64url)
  signing_input="${header}.${payload}"
  # ES256 = ECDSA-P256-SHA256; openssl liefert DER, Apple erwartet rohes r||s.
  sig=$(printf '%s' "$signing_input" \
    | openssl dgst -sha256 -sign "$ASC_KEY_PATH" \
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

# asc_get <pfad-mit-query>
# Eckige Klammern muessen als %5B/%5D kodiert sein, sonst bricht curl mit
# "bad range in URL" ab.
asc_get() {
  curl -fsS -m 30 -H "Authorization: Bearer $(asc_jwt)" \
    "https://api.appstoreconnect.apple.com$1"
}
