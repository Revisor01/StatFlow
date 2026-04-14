export type Copy = {
  de: { headline: string; subline: string };
  en: { headline: string; subline: string };
  fr: { headline: string; subline: string };
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
    fr: {
      headline: "Ton site web.\nToujours en vue.",
      subline: "Visiteurs, pages vues, taux de rebond.\nTout d'un coup d'œil.",
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
    fr: {
      headline: "Creuse plus loin.\nEn quelques secondes.",
      subline: "Pages, référents, navigateurs, pays —\ntous les détails, instantanément.",
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
    fr: {
      headline: "En direct.",
      subline: "Qui est sur ton site en ce moment ?\nSuis-le en temps réel.",
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
    fr: {
      headline: "Cette semaine\nvs. la semaine dernière.",
      subline: "Compare n'importe quelles périodes.\nRepère les tendances immédiatement.",
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
    fr: {
      headline: "Événements.\nEntonnoirs. UTM.",
      subline: "Événements personnalisés, entonnoirs\net attribution — tout en un.",
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
    fr: {
      headline: "Sans ouvrir.\nJuste un coup d'œil.",
      subline: "Le widget StatFlow affiche tes\nchiffres clés sur l'écran d'accueil.",
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
    fr: {
      headline: "Umami. Plausible.\nUne seule app.",
      subline: "Tous tes comptes, tous tes sites —\nchange d'un seul tap.",
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
    fr: {
      headline: "Configure.\nC'est parti.",
      subline: "Saisis l'URL de ton serveur, connecte-toi —\nton tableau de bord est prêt immédiatement.",
    },
  },

};
