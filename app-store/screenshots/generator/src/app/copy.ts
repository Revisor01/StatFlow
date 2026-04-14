export type Copy = {
  de: { headline: string; subline: string };
  en: { headline: string; subline: string };
};

export const COPY: Record<string, Copy> = {

  "01-dashboard": {
    // Layout: headline-top — stärkster Hook (D-07)
    de: {
      headline: "Deine Website.\nImmer im Blick.",
      subline: "Besucher, Seitenaufrufe, Absprungrate.\nAlles auf einen Blick.",
    },
    en: {
      headline: "Your website.\nAlways in sight.",
      subline: "Visitors, pageviews, bounce rate.\nAll at a glance.",
    },
  },

  "02-details": {
    // Layout: mock-left
    de: {
      headline: "Tiefer graben.\nIn Sekunden.",
      subline: "Seiten, Referrer, Browser, Länder —\nalle Details sofort parat.",
    },
    en: {
      headline: "Dig deeper.\nIn seconds.",
      subline: "Pages, referrers, browsers, countries —\nevery detail, instantly.",
    },
  },

  "03-realtime": {
    // Layout: mock-right — zweiter starker Hook (D-07)
    de: {
      headline: "Live dabei.",
      subline: "Wer ist gerade auf deiner Website?\nSieh es in Echtzeit.",
    },
    en: {
      headline: "Live, right now.",
      subline: "Who's on your site at this moment?\nWatch it unfold in real time.",
    },
  },

  "04-vergleich": {
    // Layout: headline-top
    de: {
      headline: "Diese Woche\nvs. letzte Woche.",
      subline: "Zeiträume vergleichen.\nTrends sofort erkennen.",
    },
    en: {
      headline: "This week\nvs. last week.",
      subline: "Compare any periods.\nSpot trends instantly.",
    },
  },

  "05-events": {
    // Layout: mock-left
    de: {
      headline: "Events.\nFunnels. UTM.",
      subline: "Custom Events, Conversion-Funnels\nund Attribution — alles dabei.",
    },
    en: {
      headline: "Events.\nFunnels. UTM.",
      subline: "Custom events, conversion funnels\nand attribution — all in one place.",
    },
  },

  "06-widget": {
    // Layout: mock-right
    de: {
      headline: "Kein Öffnen.\nEinfach schauen.",
      subline: "Das StatFlow-Widget zeigt dir die\nwichtigsten Zahlen auf dem Homescreen.",
    },
    en: {
      headline: "No opening.\nJust glance.",
      subline: "The StatFlow widget shows your\nkey metrics right on your home screen.",
    },
  },

  "07-account-switcher": {
    // Layout: headline-top
    de: {
      headline: "Umami. Plausible.\nEine App.",
      subline: "Alle Accounts, alle Websites —\nmit einem Tap wechseln.",
    },
    en: {
      headline: "Umami. Plausible.\nOne app.",
      subline: "All accounts, all websites —\nswitch with a single tap.",
    },
  },

  "08-start": {
    // Layout: mock-left
    de: {
      headline: "Einrichten.\nLoslegen.",
      subline: "Server-URL eingeben, anmelden —\ndein Dashboard ist sofort bereit.",
    },
    en: {
      headline: "Set up.\nDive in.",
      subline: "Enter your server URL, sign in —\nyour dashboard is ready instantly.",
    },
  },

};
