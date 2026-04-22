#!/usr/bin/env ts-node
import * as fs from "fs";
import * as crypto from "crypto";
import { ascFetch, withRetry, AscApiError } from "./lib/asc-api";
import {
  APP_BUNDLE_ID,
  APP_VERSION_STRING,
  LOCALES,
  METADATA,
  REVIEW_NOTES,
  SCREENSHOT_DISPLAY_TYPE,
  SCREENSHOT_BASE_PATH,
  SLIDE_IDS,
  screenshotPath,
  type LocaleKey,
} from "./lib/config";

// --- CLI Args ---
const DRY_RUN = process.argv.includes("--dry-run");
const SKIP_SCREENSHOTS = process.argv.includes("--skip-screenshots");

function log(msg: string): void {
  console.log(`[${new Date().toISOString()}] ${msg}`);
}

function dryLog(msg: string): void {
  if (DRY_RUN) console.log(`  [DRY-RUN] ${msg}`);
}

// --- Step 0: Preflight — alle PNGs prüfen ---
async function preflight(): Promise<void> {
  log("Step 0: Preflight — PNG-Dateien prüfen...");
  const missing: string[] = [];
  const expected = SLIDE_IDS.length * Object.keys(LOCALES).length;
  for (const locale of Object.keys(LOCALES) as LocaleKey[]) {
    for (const slide of SLIDE_IDS) {
      const p = screenshotPath(locale, slide);
      if (!fs.existsSync(p)) missing.push(p);
    }
  }
  if (missing.length > 0) {
    console.error("FEHLER: Fehlende Screenshot-Dateien:");
    missing.forEach((p) => console.error(`  - ${p}`));
    console.error("\nBitte zuerst Plan 04 abschließen (Screenshots exportieren).");
    console.error("Alternativ: mit --skip-screenshots aufrufen, um nur Metadaten zu submitten.");
    if (!SKIP_SCREENSHOTS) process.exit(1);
  } else {
    log(`  ✓ Alle ${expected} PNGs vorhanden in ${SCREENSHOT_BASE_PATH}`);
  }
}

// --- Step 1: App-ID holen ---
// Sparse fieldsets (fields[apps]=bundleId) minimiert Response-Payload.
async function getAppId(): Promise<string> {
  log(`Step 1: App-ID für Bundle-ID ${APP_BUNDLE_ID} holen...`);
  const query = `/v1/apps?filter[bundleId]=${APP_BUNDLE_ID}&fields[apps]=bundleId&limit=1`;
  if (DRY_RUN) {
    dryLog(`GET ${query}`);
    return "DRY_RUN_APP_ID";
  }
  const res = await ascFetch<{ data: Array<{ id: string }> }>(query);
  const appId = res.data[0]?.id;
  if (!appId) throw new Error(`App mit Bundle-ID ${APP_BUNDLE_ID} nicht gefunden`);
  log(`  ✓ App-ID: ${appId}`);
  return appId;
}

// --- Step 2: App Store Version prüfen/anlegen ---
async function getOrCreateVersion(appId: string): Promise<string> {
  log(`Step 2: Version ${APP_VERSION_STRING} prüfen...`);
  if (DRY_RUN) {
    dryLog(`GET /v1/apps/${appId}/appStoreVersions`);
    return "DRY_RUN_VERSION_ID";
  }

  const versionsRes = await ascFetch<{
    data: Array<{
      id: string;
      attributes: { versionString: string; appStoreState: string };
    }>;
  }>(
    `/v1/apps/${appId}/appStoreVersions?filter[platform]=IOS&filter[appStoreState]=PREPARE_FOR_SUBMISSION,READY_FOR_REVIEW,WAITING_FOR_REVIEW&fields[appStoreVersions]=versionString,appStoreState&limit=10`
  );

  const existing = versionsRes.data.find(
    (v) => v.attributes.versionString === APP_VERSION_STRING
  );
  if (existing) {
    log(
      `  ✓ Version ${APP_VERSION_STRING} existiert: ${existing.id} (${existing.attributes.appStoreState})`
    );
    return existing.id;
  }

  log(`  Lege neue Version ${APP_VERSION_STRING} an...`);
  const created = await ascFetch<{ data: { id: string } }>(
    "/v1/appStoreVersions",
    {
      method: "POST",
      body: JSON.stringify({
        data: {
          type: "appStoreVersions",
          attributes: {
            versionString: APP_VERSION_STRING,
            platform: "IOS",
          },
          relationships: {
            app: { data: { type: "apps", id: appId } },
          },
        },
      }),
    }
  );
  log(`  ✓ Neue Version angelegt: ${created.data.id}`);
  return created.data.id;
}

// --- Step 3: AppInfo-ID holen (für Subtitle, Pitfall 2) ---
async function getAppInfoId(appId: string): Promise<string> {
  log("Step 3: AppInfo-ID holen (für Subtitle)...");
  if (DRY_RUN) {
    dryLog(`GET /v1/apps/${appId}/appInfos`);
    return "DRY_RUN_APP_INFO_ID";
  }
  const res = await ascFetch<{ data: Array<{ id: string }> }>(
    `/v1/apps/${appId}/appInfos`
  );
  const appInfoId = res.data[0]?.id;
  if (!appInfoId) throw new Error("appInfoId nicht gefunden");
  log(`  ✓ AppInfo-ID: ${appInfoId}`);
  return appInfoId;
}

// --- Step 4: Metadaten setzen ---
// Gibt Mapping locale → appStoreVersionLocalization-ID zurück; wird in Step 5
// als Input benötigt.
async function setVersionMetadata(
  versionId: string,
  appInfoId: string
): Promise<Record<string, string>> {
  log("Step 4: Metadaten setzen (Description, Keywords, Promotional Text, What's New)...");

  const versionLocIds: Record<string, string> = {};
  if (!DRY_RUN) {
    const locRes = await ascFetch<{
      data: Array<{ id: string; attributes: { locale: string } }>;
    }>(
      `/v1/appStoreVersions/${versionId}/appStoreVersionLocalizations?fields[appStoreVersionLocalizations]=locale&limit=50`
    );
    for (const l of locRes.data) {
      versionLocIds[l.attributes.locale] = l.id;
    }
  }

  for (const [locKey, locCode] of Object.entries(LOCALES) as [LocaleKey, string][]) {
    const meta = METADATA[locKey];
    log(`  Locale ${locCode}...`);

    if (DRY_RUN) {
      dryLog(
        `POST/PATCH appStoreVersionLocalizations: ${locCode} — description (${meta.description.length} chars), keywords, promoText, whatsNew`
      );
      dryLog(`POST/PATCH appInfoLocalizations: ${locCode} — subtitle="${meta.subtitle}"`);
      continue;
    }

    // AppStoreVersionLocalization (Description, Keywords, PromoText)
    // Note: whatsNew cannot be set on initial version (409 STATE_ERROR from Apple).
    // Only include it for updates (when version already has a release).
    const versionLocPayload: Record<string, string> = {
      description: meta.description,
      keywords: meta.keywords,
      promotionalText: meta.promotionalText,
    };

    if (versionLocIds[locCode]) {
      await withRetry(() =>
        ascFetch(`/v1/appStoreVersionLocalizations/${versionLocIds[locCode]}`, {
          method: "PATCH",
          body: JSON.stringify({
            data: {
              type: "appStoreVersionLocalizations",
              id: versionLocIds[locCode],
              attributes: versionLocPayload,
            },
          }),
        })
      );
      log(`    ✓ PATCH appStoreVersionLocalization (${locCode})`);
    } else {
      const created = await withRetry(() =>
        ascFetch<{ data: { id: string } }>("/v1/appStoreVersionLocalizations", {
          method: "POST",
          body: JSON.stringify({
            data: {
              type: "appStoreVersionLocalizations",
              attributes: { locale: locCode, ...versionLocPayload },
              relationships: {
                appStoreVersion: {
                  data: { type: "appStoreVersions", id: versionId },
                },
              },
            },
          }),
        })
      );
      versionLocIds[locCode] = created.data.id;
      log(`    ✓ POST appStoreVersionLocalization (${locCode}) → id=${created.data.id}`);
    }

    // AppInfoLocalization (Subtitle + Name) — Pitfall 2: MUSS appInfoLocalizations sein
    await withRetry(() =>
      ascFetch("/v1/appInfoLocalizations", {
        method: "POST",
        body: JSON.stringify({
          data: {
            type: "appInfoLocalizations",
            attributes: {
              locale: locCode,
              name: meta.name,
              subtitle: meta.subtitle,
            },
            relationships: {
              appInfo: { data: { type: "appInfos", id: appInfoId } },
            },
          },
        }),
      })
    ).catch(async (err) => {
      // Existiert bereits → PATCH auf existierende ID
      if (err instanceof AscApiError && err.status === 409) {
        const appInfoLocRes = await ascFetch<{
          data: Array<{ id: string; attributes: { locale: string } }>;
        }>(
          `/v1/appInfos/${appInfoId}/appInfoLocalizations?fields[appInfoLocalizations]=locale&limit=50`
        );
        const existing = appInfoLocRes.data.find(
          (l) => l.attributes.locale === locCode
        );
        if (existing) {
          await withRetry(() =>
            ascFetch(`/v1/appInfoLocalizations/${existing.id}`, {
              method: "PATCH",
              body: JSON.stringify({
                data: {
                  type: "appInfoLocalizations",
                  id: existing.id,
                  attributes: { name: meta.name, subtitle: meta.subtitle },
                },
              }),
            })
          );
          log(`    ✓ PATCH appInfoLocalization subtitle (${locCode})`);
        }
      } else {
        throw err;
      }
    });
    log(`    ✓ AppInfoLocalization subtitle gesetzt (${locCode}: "${meta.subtitle}")`);
  }

  return versionLocIds;
}

// --- Step 5: Screenshots hochladen (Pattern 4: 3-Schritt) ---
async function uploadScreenshots(
  versionLocIds: Record<string, string>
): Promise<void> {
  if (SKIP_SCREENSHOTS) {
    log("Step 5: Screenshots übersprungen (--skip-screenshots)");
    return;
  }
  log(`Step 5: Screenshots hochladen (${SCREENSHOT_DISPLAY_TYPE})...`);

  for (const [locKey, locCode] of Object.entries(LOCALES) as [LocaleKey, string][]) {
    log(`  Locale ${locCode}...`);
    if (DRY_RUN) {
      dryLog(
        `POST /v1/appScreenshotSets (type=${SCREENSHOT_DISPLAY_TYPE}, locale=${locCode})`
      );
      dryLog(`Upload ${SLIDE_IDS.length} Screenshots für ${locCode}`);
      continue;
    }

    const versionLocId = versionLocIds[locCode];
    if (!versionLocId) {
      throw new Error(
        `Fehler: keine appStoreVersionLocalization-ID für ${locCode} gefunden. Step 4 muss zuerst laufen.`
      );
    }

    // Screenshot-Set anlegen
    let screenshotSetId: string;
    try {
      const setRes = await withRetry(() =>
        ascFetch<{ data: { id: string } }>("/v1/appScreenshotSets", {
          method: "POST",
          body: JSON.stringify({
            data: {
              type: "appScreenshotSets",
              attributes: {
                screenshotDisplayType: SCREENSHOT_DISPLAY_TYPE,
              },
              relationships: {
                appStoreVersionLocalization: {
                  data: {
                    type: "appStoreVersionLocalizations",
                    id: versionLocId,
                  },
                },
              },
            },
          }),
        })
      );
      screenshotSetId = setRes.data.id;
    } catch (err) {
      if (err instanceof AscApiError && err.status === 422) {
        console.warn(
          `\n⚠️  422 beim Anlegen des Screenshot-Sets für ${locCode} mit ${SCREENSHOT_DISPLAY_TYPE}.`
        );
        console.warn(
          "   Möglicherweise hat Apple den API-Spec noch nicht auf 6.9\" aktualisiert."
        );
        console.warn(
          `   MANUAL FALLBACK: Screenshots für ${locCode} manuell in ASC hochladen:`
        );
        console.warn(`   1. Öffne https://appstoreconnect.apple.com`);
        console.warn(`   2. StatsFlow → Version ${APP_VERSION_STRING} → ${locCode}`);
        console.warn(
          `   3. Lade alle ${SLIDE_IDS.length} PNGs aus app-store/screenshots/export/${locKey}/ hoch`
        );
        continue;
      }
      throw err;
    }

    // Pro Screenshot: 3-Schritt-Upload
    for (let i = 0; i < SLIDE_IDS.length; i++) {
      const slideId = SLIDE_IDS[i];
      const pngPath = screenshotPath(locKey, slideId);
      const fileBytes = fs.readFileSync(pngPath);
      const fileName = `${slideId}-${locKey}.png`;

      log(`    Upload ${fileName} (${Math.round(fileBytes.length / 1024)}KB)...`);

      // Schritt 1: Reservation mit uploadOperations[]
      const reservation = await withRetry(() =>
        ascFetch<{
          data: {
            id: string;
            attributes: {
              uploadOperations: Array<{
                method: string;
                url: string;
                offset: number;
                length: number;
                requestHeaders: Array<{ name: string; value: string }>;
              }>;
            };
          };
        }>("/v1/appScreenshots", {
          method: "POST",
          body: JSON.stringify({
            data: {
              type: "appScreenshots",
              attributes: { fileName, fileSize: fileBytes.length },
              relationships: {
                appScreenshotSet: {
                  data: { type: "appScreenshotSets", id: screenshotSetId },
                },
              },
            },
          }),
        })
      );

      // Schritt 2: S3-Upload pro Operation (KEIN Authorization-Header!)
      for (const op of reservation.data.attributes.uploadOperations) {
        const chunk = fileBytes.slice(op.offset, op.offset + op.length);
        const uploadRes = await fetch(op.url, {
          method: op.method,
          headers: Object.fromEntries(
            op.requestHeaders.map((h) => [h.name, h.value])
          ),
          body: chunk,
        });
        if (!uploadRes.ok)
          throw new Error(`S3 Upload fehlgeschlagen: ${uploadRes.status}`);
      }

      // Schritt 3: Commit mit MD5-Checksum
      const md5 = crypto.createHash("md5").update(fileBytes).digest("hex");
      await withRetry(() =>
        ascFetch(`/v1/appScreenshots/${reservation.data.id}`, {
          method: "PATCH",
          body: JSON.stringify({
            data: {
              type: "appScreenshots",
              id: reservation.data.id,
              attributes: { sourceFileChecksum: md5, uploaded: true },
            },
          }),
        })
      );

      log(`    ✓ ${fileName} hochgeladen`);
    }
    log(`  ✓ Alle ${SLIDE_IDS.length} Screenshots für ${locCode} fertig`);
  }
}

// --- Step 6: Review-Notes setzen ---
async function setReviewNotes(versionId: string): Promise<void> {
  log("Step 6: Review-Notes setzen...");
  if (DRY_RUN) {
    dryLog(`POST/PATCH /v1/appStoreReviewDetails: reviewContactEmail, notes`);
    return;
  }

  try {
    await ascFetch("/v1/appStoreReviewDetails", {
      method: "POST",
      body: JSON.stringify({
        data: {
          type: "appStoreReviewDetails",
          attributes: {
            contactFirstName: "Simon",
            contactLastName: "Luthe",
            contactEmail: "mail@simonluthe.de",
            contactPhone: "",
            notes: REVIEW_NOTES,
            demoAccountName: process.env.ASC_DEMO_ACCOUNT_NAME ?? "admin",
            demoAccountPassword: process.env.ASC_DEMO_ACCOUNT_PASSWORD ?? "",
            demoAccountRequired: true,
          },
          relationships: {
            appStoreVersion: {
              data: { type: "appStoreVersions", id: versionId },
            },
          },
        },
      }),
    });
    log("  ✓ Review-Notes gesetzt");
  } catch (err) {
    if (err instanceof AscApiError && err.status === 409) {
      log(
        "  ⚠ Review-Notes existieren bereits (PATCH wäre nötig — manuell prüfen in ASC)"
      );
    } else {
      throw err;
    }
  }
}

// --- Step 7: Submit for Review ---
// LOW confidence laut RESEARCH.md — Confirm-Endpunkt nicht voll verifiziert.
// Manueller Fallback wird dokumentiert ausgegeben.
async function submitForReview(
  appId: string,
  versionId: string
): Promise<void> {
  log("Step 7: Submit for Review...");
  if (DRY_RUN) {
    dryLog(`POST /v1/reviewSubmissions { platform: IOS }`);
    dryLog(`POST /v1/reviewSubmissionItems { reviewSubmission.id, appStoreVersion.id }`);
    return;
  }

  try {
    const submissionRes = await ascFetch<{ data: { id: string } }>(
      "/v1/reviewSubmissions",
      {
        method: "POST",
        body: JSON.stringify({
          data: {
            type: "reviewSubmissions",
            attributes: { platform: "IOS" },
            relationships: {
              app: { data: { type: "apps", id: appId } },
            },
          },
        }),
      }
    );
    const submissionId = submissionRes.data.id;
    log(`  ✓ ReviewSubmission angelegt: ${submissionId}`);

    await ascFetch("/v1/reviewSubmissionItems", {
      method: "POST",
      body: JSON.stringify({
        data: {
          type: "reviewSubmissionItems",
          relationships: {
            reviewSubmission: {
              data: { type: "reviewSubmissions", id: submissionId },
            },
            appStoreVersion: {
              data: { type: "appStoreVersions", id: versionId },
            },
          },
        },
      }),
    });
    log("  ✓ ReviewSubmissionItem angelegt");

    log("  ℹ Submit-for-Review Trigger: versuche confirmReviewSubmission...");
    await ascFetch(`/v1/reviewSubmissions/${submissionId}/confirm`, {
      method: "POST",
      body: JSON.stringify({}),
    });
    log("  ✓ Submission eingereicht!");
  } catch (err) {
    console.warn("\n⚠️  Submit-for-Review via API fehlgeschlagen.");
    console.warn(
      "   Das ist bekannt — der API-Endpunkt für den finalen Submit-Trigger ist LOW-confidence."
    );
    console.warn("\n   MANUAL FALLBACK (ASC-UI):");
    console.warn("   1. Öffne https://appstoreconnect.apple.com");
    console.warn(`   2. StatsFlow → Version ${APP_VERSION_STRING}`);
    console.warn(
      "   3. Prüfe: Pricing, Availability, Age Rating, Encryption Declaration"
    );
    console.warn("   4. Klicke 'Add for Review' → 'Submit to App Review'");
    console.warn(
      "\n   Alle anderen Schritte (Metadaten, Screenshots, Localizations) wurden via API gesetzt."
    );
  }
}

// --- Main ---
async function main(): Promise<void> {
  console.log("\n=== StatsFlow ASC Submission Script ===");
  if (DRY_RUN) console.log("MODE: DRY-RUN (keine API-Calls)");
  if (SKIP_SCREENSHOTS) console.log("MODE: --skip-screenshots aktiv");
  console.log("");

  // Env-Var-Check
  if (!DRY_RUN) {
    const required = [
      "APP_STORE_CONNECT_KEY_ID",
      "APP_STORE_CONNECT_ISSUER_ID",
      "APP_STORE_CONNECT_KEY_PATH",
    ];
    const missing = required.filter((k) => !process.env[k]);
    if (missing.length > 0) {
      console.error("FEHLER: Fehlende Env-Vars:", missing.join(", "));
      console.error(
        "Ausführung: source ~/.claude/secrets.env && npx ts-node submit.ts"
      );
      process.exit(1);
    }
  }

  await preflight();
  const appId = await getAppId();
  const versionId = await getOrCreateVersion(appId);
  const appInfoId = await getAppInfoId(appId);
  const versionLocIds = await setVersionMetadata(versionId, appInfoId);
  await uploadScreenshots(versionLocIds);
  await setReviewNotes(versionId);
  await submitForReview(appId, versionId);

  console.log("\n=== Submission abgeschlossen ===");
  if (!DRY_RUN) {
    console.log("\nManuelle Restschritte in ASC-UI:");
    console.log("  - [ ] Pricing & Availability gesetzt?");
    console.log("  - [ ] Age Rating: 4+ ?");
    console.log("  - [ ] Encryption Declaration: 'No encryption' ?");
    console.log("  - [ ] Content Rights: keine Third-Party-Inhalte ?");
    console.log("  - [ ] Build hochgeladen (via Xcode Organizer)?");
    console.log("  - [ ] Submit-for-Review ausgelöst (API oder manuell)?");
    console.log("\nASC: https://appstoreconnect.apple.com");
  }
}

main().catch((err) => {
  console.error("\nFEHLER:", err);
  process.exit(1);
});
