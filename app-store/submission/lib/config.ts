import * as path from "path";

// --- App Identifiers ---
export const APP_BUNDLE_ID = "de.godsapp.statflow";
export const APP_VERSION_STRING = "1.0";

// --- Locale-Codes (BCP-47, Pitfall 5) ---
export const LOCALES = {
  de: "de-DE",
  en: "en-US",
} as const;

export type LocaleKey = keyof typeof LOCALES;

// --- Screenshot Paths ---
// lib/config.ts liegt in app-store/submission/lib/ → 3x hochgehen → Repo-Root.
const REPO_ROOT = path.resolve(__dirname, "../../..");
export const SCREENSHOT_BASE_PATH = path.join(
  REPO_ROOT,
  "app-store/screenshots/export"
);

export const SLIDE_IDS = [
  "01-dashboard",
  "02-details",
  "03-breakdown",
  "04-realtime",
  "05-vergleich",
  "06-events",
  "07-combo",
  "08-account-switcher",
  "09-add-account",
] as const;

export type SlideId = (typeof SLIDE_IDS)[number];

export function screenshotPath(locale: LocaleKey, slideId: SlideId): string {
  return path.join(SCREENSHOT_BASE_PATH, locale, `${slideId}-${locale}.png`);
}

// --- ASC Screenshot Display Type ---
// RESEARCH.md: APP_IPHONE_69 existiert NICHT im OpenAPI-Spec (Stand April 2026).
// Primär APP_IPHONE_67 verwenden; bei 422 → manueller Upload-Fallback.
export const SCREENSHOT_DISPLAY_TYPE = "APP_IPHONE_67";

// --- App Store Metadata ---
// Alle Texte direkt aus app-store/description.md übernommen.
export const METADATA: Record<
  LocaleKey,
  {
    name: string;
    subtitle: string;
    keywords: string;
    description: string;
    promotionalText: string;
    whatsNew: string;
  }
> = {
  de: {
    name: "StatsFlow",
    subtitle: "Analytics Dashboard für iPhone",
    keywords:
      "analytics,umami,plausible,statistik,dashboard,website,tracking,besucher,self-hosted,datenschutz",
    description: `Deine Website-Zahlen. Immer dabei.

StatsFlow bringt dein Analytics-Dashboard aufs iPhone — für Umami und Plausible Analytics. Schnell, sicher und ohne Umwege.

Wer eine Website betreibt und auf datenschutzfreundliche Analytics setzt, kennt das Problem: Um die Besucherzahlen zu checken, muss man sich jedes Mal am Desktop einloggen. StatsFlow macht Schluss damit. Eine App, alle Accounts, alle Websites.

MULTI-ACCOUNT & MULTI-PROVIDER
Verwalte beliebig viele Umami- und Plausible-Accounts in einer App. Wechsle zwischen Accounts mit einem Tap oder sieh alle Websites aller Accounts in einer kombinierten Ansicht.

DASHBOARD MIT SPARKLINES
Die Übersicht zeigt dir sofort, was auf deinen Websites passiert: Besucher, Seitenaufrufe, Verweildauer und Absprungrate — alles mit kompakten Sparkline-Charts für den schnellen Trend-Check.

ECHTZEIT-ANSICHT
Wer ist gerade auf deiner Website? Die Realtime-View zeigt dir Live-Besucher, aktuelle Seiten und Referrer in Echtzeit.

ZEITRAUMVERGLEICH
Vergleiche beliebige Zeiträume miteinander: Diese Woche vs. letzte Woche, dieser Monat vs. Vormonat. So erkennst du Trends sofort.

EVENTS & REPORTS
Detaillierte Auswertungen für Custom Events, Funnel-Analysen, UTM-Tracking, Goals und Attribution — alles direkt in der App.

WIDGET FÜR DEN HOMESCREEN
Ein Blick auf den Homescreen genügt: Das StatsFlow-Widget zeigt dir die wichtigsten Zahlen deiner Website, ohne die App zu öffnen.

OFFLINE-MODUS
Kein Netz? Kein Problem. StatsFlow zeigt dir die zuletzt geladenen Daten als Fallback an, damit du auch unterwegs nicht im Dunkeln tappst.

DATENSCHUTZ
- Keine Tracking-SDKs — die App selbst enthält keinerlei Analytics oder Tracking
- Keine Werbung — komplett werbefrei
- Credentials im Keychain — deine Zugangsdaten werden sicher in der iOS Keychain gespeichert
- Keine Datensammlung — die App kommuniziert ausschließlich mit deinen eigenen Servern
- Keine externen Dependencies — komplett in SwiftUI gebaut, ohne Drittanbieter-Bibliotheken

TECHNIK
StatsFlow ist eine native iOS-App, komplett in Swift und SwiftUI gebaut. Keine externen Abhängigkeiten, keine Drittanbieter-Frameworks. Deine Daten bleiben auf deinem Gerät und deinen Servern.

Für Website-Betreiber, die ihre Self-Hosted Analytics auch unterwegs im Blick behalten wollen.`,
    promotionalText:
      "Dein Analytics-Dashboard für unterwegs. Umami und Plausible Analytics sicher auf dem iPhone — mit Echtzeit-Daten, Widgets und Zeitraumvergleich.",
    whatsNew:
      "Erste Veröffentlichung im App Store! Dashboard, Echtzeit-Ansicht, Zeitraumvergleich, Events, Reports, Widget und Offline-Modus — alles für Umami und Plausible Analytics.",
  },

  en: {
    name: "StatsFlow",
    subtitle: "Analytics Dashboard for iPhone",
    keywords:
      "analytics,umami,plausible,statistics,dashboard,website,tracking,visitors,self-hosted,privacy",
    description: `Your website stats. Always with you.

StatsFlow brings your analytics dashboard to your iPhone — for Umami and Plausible Analytics. Fast, secure, and straightforward.

If you run a website with privacy-friendly analytics, you know the problem: checking your visitor stats means logging in on a desktop every time. StatsFlow changes that. One app, all accounts, all websites.

MULTI-ACCOUNT & MULTI-PROVIDER
Manage any number of Umami and Plausible accounts in one app. Switch between accounts with a tap or view all websites across all accounts in a combined view.

DASHBOARD WITH SPARKLINES
The overview shows you instantly what's happening on your websites: visitors, pageviews, session duration, and bounce rate — all with compact sparkline charts for quick trend checks.

REALTIME VIEW
Who's on your website right now? The realtime view shows you live visitors, current pages, and referrers as they happen.

PERIOD COMPARISON
Compare any time periods: this week vs. last week, this month vs. last month. Spot trends immediately.

EVENTS & REPORTS
Detailed analytics for custom events, funnel analysis, UTM tracking, goals, and attribution — all right in the app.

HOMESCREEN WIDGET
One glance at your homescreen is all it takes: the StatsFlow widget shows your website's key metrics without opening the app.

OFFLINE MODE
No connection? No problem. StatsFlow shows your last loaded data as a fallback, so you're never in the dark while on the go.

PRIVACY
- No tracking SDKs — the app itself contains zero analytics or tracking
- No ads — completely ad-free
- Credentials in Keychain — your login data is securely stored in iOS Keychain
- No data collection — the app communicates exclusively with your own servers
- No external dependencies — built entirely in SwiftUI, no third-party libraries

TECHNOLOGY
StatsFlow is a native iOS app built entirely in Swift and SwiftUI. No external dependencies, no third-party frameworks. Your data stays on your device and your servers.

For website owners who want to keep their self-hosted analytics in sight while on the go.`,
    promotionalText:
      "Your analytics dashboard on the go. Umami and Plausible Analytics on your iPhone — with realtime data, widgets, and period comparison.",
    whatsNew:
      "First App Store release! Dashboard, realtime view, period comparison, events, reports, widget, and offline mode — all for Umami and Plausible Analytics.",
  },
};

// --- App Review Notes ---
// Aus app-store/review-notes.md übernommen (Test-Accounts in app-store/secrets.md).
export const REVIEW_NOTES = `Test Account 1 — Umami Analytics:
Server URL: https://t.godsapp.de
Username: admin
Password: rn%MWru13

Steps:
1. Open app, tap "Account hinzufügen" (Add Account)
2. Select "Umami" as provider, then "Self-hosted"
3. Enter server URL, username, and password
4. Tap "Anmelden" (Sign In) — dashboard loads with test websites

Test Account 2 — Plausible Analytics:
Server URL: https://plausible.godsapp.de
API Key: 4uJEjvR5JiXZuQRm84fM4C3wMvQqVPgF2xBUiSlSCRcz1Vu4zt1qvEQ0BtDU5U2S

Steps:
1. Tap "Account hinzufügen"
2. Select "Plausible" as provider, then "Self-hosted"
3. Enter server URL and API key
4. Tap "Anmelden" — dashboard loads with 3 test websites

Note: StatsFlow connects to the user's own self-hosted Umami or Plausible Analytics server. No data is sent to the developer. All credentials are stored locally in iOS Keychain.`;

// --- URLs ---
export const PRIVACY_POLICY_URL =
  "https://simonluthe.de/apps/statsflow/datenschutz/";
export const SUPPORT_URL = "https://simonluthe.de/apps/statsflow/";
export const MARKETING_URL = "https://simonluthe.de/apps/statsflow/";
