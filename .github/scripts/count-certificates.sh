#!/usr/bin/env bash
# Zaehlt die Development-Zertifikate des Kontos und schlaegt Alarm, wenn das
# Limit erreicht ist.
#
# Warum: Apple erlaubt zwei Development-Zertifikate je Konto. Solange der
# Build automatisch signierte, legte jeder Lauf ein weiteres an — bis der
# naechste mit "Choose a certificate to revoke" abbrach. Die Meldung liest
# sich wie ein Profil-Problem und kostete einen Abend Suche.
#
# Seit der Umstellung auf manuelle Signierung soll die Zahl stehen bleiben.
# Dieser Schritt ist die Probe darauf: steigt sie doch, greift der Umbau
# irgendwo nicht und das faellt beim naechsten Lauf auf, nicht erst, wenn
# das Limit voll ist und ein Release wartet.
#
# Erwartet: ASC_KEY_ID, ASC_ISSUER_ID und den .p8 unter
# ~/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8
set -euo pipefail

source "$(dirname "$0")/asc-jwt.sh"

asc_get "/v1/certificates?limit=100&fields%5Bcertificates%5D=certificateType,displayName,expirationDate" \
  | python3 -c '
import sys, json
from collections import Counter
from datetime import datetime, timezone

daten = json.load(sys.stdin)["data"]
zahl = Counter(r["attributes"]["certificateType"] for r in daten)
for typ, n in sorted(zahl.items()):
    print("  %-18s %d" % (typ, n))

# Apple zaehlt beide Development-Varianten gegen dasselbe Limit von zwei.
dev = zahl.get("DEVELOPMENT", 0) + zahl.get("IOS_DEVELOPMENT", 0)
print("Development-Zertifikate: %d" % dev)

# Das Distribution-Zertifikat traegt alle Store-Uploads. Laeuft es ab, steht
# die Auslieferung — rechtzeitig sichtbar machen.
for r in daten:
    a = r["attributes"]
    if a["certificateType"] == "DISTRIBUTION":
        rest = (datetime.fromisoformat(a["expirationDate"]) - datetime.now(timezone.utc)).days
        print("Distribution %r laeuft in %d Tagen ab (%s)" % (a["displayName"], rest, a["expirationDate"][:10]))
        if rest < 30:
            print("ACHTUNG: Distribution-Zertifikat laeuft bald ab — erneuern, sonst stehen die Uploads.")

if dev > 2:
    # Erst die Zahlen rausschreiben, dann die Diagnose — sonst steht im Log
    # die Schlussfolgerung vor dem, worauf sie sich stuetzt.
    sys.stdout.flush()
    sys.exit(
        "\nFEHLER: %d Development-Zertifikate — das Limit von zwei ist ueberschritten.\n"
        "Der Build legt wieder welche an. Pruefen, ob irgendwo noch\n"
        "-allowProvisioningUpdates oder CODE_SIGN_STYLE = Automatic steht.\n"
        "Ueberzaehlige widerrufen, sonst scheitert der naechste Build." % dev)
'
