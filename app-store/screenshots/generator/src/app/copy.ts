export type Copy = {
  de: { headline: string; subline: string };
  en: { headline: string; subline: string };
};

export const COPY: Record<string, Copy> = {

  "01-dashboard": {
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
    de: {
      headline: "Tiefer graben.\nIn Sekunden.",
      subline: "Aufrufe, Besucher, Verweildauer —\njedes Detail sofort parat.",
    },
    en: {
      headline: "Dig deeper.\nIn seconds.",
      subline: "Pageviews, visitors, duration —\nevery detail, instantly.",
    },
  },

  "03-breakdown": {
    de: {
      headline: "Wer kommt\nwoher.",
      subline: "Geräte, Browser, Betriebssysteme,\nSprachen — alles aufgeschlüsselt.",
    },
    en: {
      headline: "Who visits.\nFrom where.",
      subline: "Devices, browsers, operating systems,\nlanguages — all broken down.",
    },
  },

  "04-realtime": {
    de: {
      headline: "Live dabei.",
      subline: "Wer ist gerade auf deiner Website?\nSieh es in Echtzeit.",
    },
    en: {
      headline: "Live, right now.",
      subline: "Who's on your site at this moment?\nWatch it unfold in real time.",
    },
  },

  "05-vergleich": {
    de: {
      headline: "Vergleichen.\nSofort verstehen.",
      subline: "Wochen, Monate, Jahre —\njeden Zeitraum nebeneinander.",
    },
    en: {
      headline: "Compare.\nUnderstand.",
      subline: "Weeks, months, years —\nany period, side by side.",
    },
  },

  "06-events": {
    de: {
      headline: "Events.\nFunnels. UTM.",
      subline: "Custom Events, Conversion-Funnels\nund Attribution — alles dabei.",
    },
    en: {
      headline: "Events.\nFunnels. UTM.",
      subline: "Custom events, conversion funnels\nand attribution — all in one place.",
    },
  },

  "07-combo": {
    de: {
      headline: "Immer informiert.\nOhne Öffnen.",
      subline: "Notification am Morgen, Widget\nauf dem Homescreen — du verpasst nichts.",
    },
    en: {
      headline: "Always informed.\nWithout opening.",
      subline: "Morning notification, widget\non your home screen — you miss nothing.",
    },
  },

  "08-account-switcher": {
    de: {
      headline: "Umami. Plausible.\nEine App.",
      subline: "Alle Accounts, alle Websites —\nmit einem Tap wechseln.",
    },
    en: {
      headline: "Umami. Plausible.\nOne app.",
      subline: "All accounts, all websites —\nswitch with a single tap.",
    },
  },

  "09-add-account": {
    de: {
      headline: "Einrichten.\nLoslegen.",
      subline: "Server-URL eingeben, anmelden —\ndein Dashboard ist sofort bereit.",
    },
    en: {
      headline: "Set up.\nDive in.",
      subline: "Enter your server URL, sign in —\nyour dashboard is ready.",
    },
  },

};
