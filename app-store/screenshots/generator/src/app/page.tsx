"use client";

import { useRef, useState } from "react";
import { toPng } from "html-to-image";
import { COPY } from "./copy";

const THEME = {
  bgFrom: "#FAFAF7",
  bgTo: "#F0F0EC",
  blobLight: "#FFFFFF",
  blobMid: "#F5F5F0",
  blobDark: "#E8E8E2",
  textPrimary: "#000000",
  textSecondary: "rgba(0,0,0,0.65)",
} as const;

const CANVAS_W = 1320;
const CANVAS_H = 2868;

type Layout = "headline-top" | "brush-bg" | "mock-tilt" | "combo";
type Locale = "de" | "en";

type Slide = {
  id: string;
  locale: Locale;
  headline: string;
  subline: string;
  screenshot: string;
  screenshot2?: string; // für combo-Layout (zweites Bild)
  layout: Layout;
  bgVariant: 0 | 1 | 2;
};

const SCREEN_IDS = [
  "01-dashboard",
  "02-details",
  "03-breakdown",
  "04-realtime",
  "05-vergleich",
  "06-events",
  "07-combo",         // Notification + Widget in einem Slide
  "08-account-switcher",
  "09-add-account",
] as const;

const LAYOUT_ROTATION: Layout[] = [
  "headline-top", // 01 Dashboard — Hero
  "mock-tilt",    // 02 Details Stats (schräg links)
  "brush-bg",     // 03 Breakdown
  "headline-top", // 04 Realtime
  "mock-tilt",    // 05 Vergleich (schräg rechts via idx)
  "brush-bg",     // 06 Events
  "combo",        // 07 Notification + Widget
  "headline-top", // 08 Account Switcher
  "mock-tilt",    // 09 Add Account
];

function sourcePath(name: string, locale: Locale): string {
  return `/screenshots/${locale}/${name}.png`;
}

// Mapping: SCREEN_ID → actual filename(s) on disk
const SCREENSHOT_FILES: Record<string, { primary: string; secondary?: string }> = {
  "01-dashboard":       { primary: "01-dashboard" },
  "02-details":         { primary: "02-details" },
  "03-breakdown":       { primary: "03-breakdown" },
  "04-realtime":        { primary: "04-realtime" },
  "05-vergleich":       { primary: "05-vergleich" },
  "06-events":          { primary: "06-events" },
  "07-combo":           { primary: "09-notification", secondary: "07-widget" },
  "08-account-switcher": { primary: "08-account-switcher" },
  "09-add-account":     { primary: "10-add-account" },
};

const SLIDES: Slide[] = SCREEN_IDS.flatMap((id, idx) =>
  (["de", "en"] as const).map((locale) => {
    const files = SCREENSHOT_FILES[id];
    return {
      id,
      locale,
      headline: COPY[id][locale].headline,
      subline: COPY[id][locale].subline,
      screenshot: sourcePath(files.primary, locale),
      screenshot2: files.secondary ? sourcePath(files.secondary, locale) : undefined,
      layout: LAYOUT_ROTATION[idx],
      bgVariant: (idx % 3) as 0 | 1 | 2,
    };
  })
);

function MultilineText({ text, nowrap = true }: { text: string; nowrap?: boolean }) {
  const lines = text.split("\n");
  return (
    <>
      {lines.map((line, i) => (
        <span key={i} style={{ whiteSpace: nowrap ? "nowrap" : "normal", display: "inline-block" }}>
          {line}
          {i < lines.length - 1 && <br />}
        </span>
      ))}
    </>
  );
}

const BG_VARIANTS = [
  // Variant 0: light blob top-right, dark blob bottom-left
  {
    gradient: `linear-gradient(145deg, ${THEME.bgFrom} 0%, ${THEME.bgTo} 100%)`,
    blobs: [
      { top: "-10%", right: "-15%", left: "auto", bottom: "auto", size: 900, color: THEME.blobLight, blur: 140, opacity: 0.15 },
      { top: "auto", right: "auto", left: "-20%", bottom: "-15%", size: 1100, color: THEME.blobDark, blur: 160, opacity: 0.12 },
      { top: "40%", right: "auto", left: "20%", bottom: "auto", size: 700, color: THEME.blobMid, blur: 120, opacity: 0.10 },
    ],
  },
  // Variant 1: light blob bottom-right, dark blob top-left
  {
    gradient: `linear-gradient(200deg, ${THEME.bgTo} 0%, ${THEME.bgFrom} 100%)`,
    blobs: [
      { top: "-15%", right: "auto", left: "-10%", bottom: "auto", size: 1000, color: THEME.blobDark, blur: 150, opacity: 0.12 },
      { top: "auto", right: "-10%", left: "auto", bottom: "-10%", size: 850, color: THEME.blobLight, blur: 130, opacity: 0.15 },
      { top: "35%", right: "60%", left: "auto", bottom: "auto", size: 600, color: THEME.blobMid, blur: 110, opacity: 0.10 },
    ],
  },
  // Variant 2: blobs centered, softer
  {
    gradient: `linear-gradient(165deg, ${THEME.bgFrom} 0%, ${THEME.bgTo} 100%)`,
    blobs: [
      { top: "5%", right: "auto", left: "50%", bottom: "auto", size: 950, color: THEME.blobLight, blur: 170, opacity: 0.13 },
      { top: "auto", right: "50%", left: "auto", bottom: "5%", size: 1000, color: THEME.blobDark, blur: 170, opacity: 0.13 },
      { top: "50%", right: "-10%", left: "auto", bottom: "auto", size: 650, color: THEME.blobMid, blur: 120, opacity: 0.10 },
    ],
  },
];

function Background({ variant }: { variant: 0 | 1 | 2 }) {
  const cfg = BG_VARIANTS[variant];
  return (
    <>
      <div style={{ position: "absolute", inset: 0, background: cfg.gradient }} />
      {cfg.blobs.map((b, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            top: b.top,
            right: b.right,
            bottom: b.bottom,
            left: b.left,
            width: b.size,
            height: b.size,
            borderRadius: "50%",
            background: b.color,
            filter: `blur(${b.blur}px)`,
            opacity: b.opacity,
            transform: b.left === "50%" || b.right === "50%" ? "translate(-50%, 0)" : undefined,
          }}
        />
      ))}
    </>
  );
}

// Ein einzelnes, riesiges Diagramm-Fragment pro Slide. Immer angeschnitten,
// beginnt außerhalb, schräg gedreht — man erahnt es nur.
const ANALYTICS_PATTERNS: React.FC[] = [
  // 0: Drei vertikale Balken — aufsteigend, 15° schräg, von unten-links reinragend
  () => (
    <svg width={CANVAS_W} height={CANVAS_H} viewBox={`0 0 ${CANVAS_W} ${CANVAS_H}`}
      style={{ position: "absolute", inset: 0, zIndex: 1, opacity: 0.06, pointerEvents: "none" }}>
      <g transform="rotate(-15, 660, 1434)">
        <rect x={100}  y={1200} width={300} height={2400} rx={24} fill="#000" />
        <rect x={520}  y={600}  width={300} height={3000} rx={24} fill="#000" />
        <rect x={940}  y={0}    width={300} height={3600} rx={24} fill="#000" />
      </g>
    </svg>
  ),
  // 1: Eine Sparkline — dicke Kurve, 10° schräg, von links-unten nach rechts-oben
  () => (
    <svg width={CANVAS_W} height={CANVAS_H} viewBox={`0 0 ${CANVAS_W} ${CANVAS_H}`}
      style={{ position: "absolute", inset: 0, zIndex: 1, opacity: 0.06, pointerEvents: "none" }}>
      <g transform="rotate(-8, 660, 1434)">
        <path d="M -300 2800 C 100 2000, 400 2400, 700 1400 C 1000 400, 1200 800, 1600 -100"
          stroke="#000" strokeWidth={24} fill="none" strokeLinecap="round" />
      </g>
    </svg>
  ),
  // 2: Ein Donut — riesig, angeschnitten von links-unten, schräg, 1/3 sichtbar
  () => (
    <svg width={CANVAS_W} height={CANVAS_H} viewBox={`0 0 ${CANVAS_W} ${CANVAS_H}`}
      style={{ position: "absolute", inset: 0, zIndex: 1, opacity: 0.06, pointerEvents: "none" }}>
      <g transform="rotate(12, -300, 2000)">
        <circle cx={-300} cy={2000} r={1400} stroke="#000" strokeWidth={220} fill="none"
          strokeDasharray="2800 5995" strokeDashoffset={-600} strokeLinecap="round" />
      </g>
    </svg>
  ),
  // 3: Fläche — geschwungene Welle, schräg, von rechts-unten reinragend
  () => (
    <svg width={CANVAS_W} height={CANVAS_H} viewBox={`0 0 ${CANVAS_W} ${CANVAS_H}`}
      style={{ position: "absolute", inset: 0, zIndex: 1, opacity: 0.06, pointerEvents: "none" }}>
      <g transform="rotate(6, 660, 1434)">
        <path d={`M -200 ${CANVAS_H + 200} L -200 2200 C 150 1500, 450 1900, 750 1100 C 1050 300, 1250 700, ${CANVAS_W + 200} 0 L ${CANVAS_W + 200} ${CANVAS_H + 200} Z`}
          fill="#000" />
      </g>
    </svg>
  ),
  // 4: Drei horizontale Balken — schräg (-12°), beginnen links außerhalb
  () => (
    <svg width={CANVAS_W} height={CANVAS_H} viewBox={`0 0 ${CANVAS_W} ${CANVAS_H}`}
      style={{ position: "absolute", inset: 0, zIndex: 1, opacity: 0.06, pointerEvents: "none" }}>
      <g transform="rotate(-12, 660, 1434)">
        <rect x={-400} y={700}  width={1600} height={220} rx={24} fill="#000" />
        <rect x={-400} y={1250} width={1200} height={220} rx={24} fill="#000" />
        <rect x={-400} y={1800} width={800}  height={220} rx={24} fill="#000" />
      </g>
    </svg>
  ),
];

function AnalyticsPattern({ slideIdx }: { slideIdx: number }) {
  const Pattern = ANALYTICS_PATTERNS[slideIdx % ANALYTICS_PATTERNS.length];
  return <Pattern />;
}

// Pinselstrich-Motiv — knüpft ans StatsFlow-Logo an (drei schwarze Balken).
// Vier Striche als Bézier-Kurven, leicht unregelmäßig (nicht zu glatt).
// Verschiedene Positionen/Opacities pro Layout — siehe Verwendung unten.
function BrushStrokes({
  opacity = 0.08,
  rotation = 0,
  scale = 1,
  top = 0,
  left = 0,
}: {
  opacity?: number;
  rotation?: number;
  scale?: number;
  top?: number | string;
  left?: number | string;
}) {
  return (
    <svg
      width={1600 * scale}
      height={1600 * scale}
      viewBox="0 0 1600 1600"
      style={{
        position: "absolute",
        top,
        left,
        opacity,
        transform: `rotate(${rotation}deg)`,
        pointerEvents: "none",
        zIndex: 1,
      }}
    >
      {/* Vier Pinselstriche, aufsteigend wie ein Balkendiagramm — StatsFlow-Logo-DNA */}
      <path
        d="M 150 1200 C 200 1190, 380 1205, 440 1195 L 440 1020 C 440 1010, 430 1005, 410 1008 L 180 1012 C 160 1014, 148 1022, 150 1200 Z"
        fill="#000000"
      />
      <path
        d="M 540 1200 C 590 1188, 770 1203, 830 1192 L 830 820 C 830 810, 820 805, 800 808 L 570 812 C 550 814, 538 822, 540 1200 Z"
        fill="#000000"
      />
      <path
        d="M 930 1200 C 980 1186, 1160 1201, 1220 1190 L 1220 620 C 1220 610, 1210 605, 1190 608 L 960 612 C 940 614, 928 622, 930 1200 Z"
        fill="#000000"
      />
      <path
        d="M 1320 1200 C 1370 1184, 1550 1199, 1610 1188 L 1610 420 C 1610 410, 1600 405, 1580 408 L 1350 412 C 1330 414, 1318 422, 1320 1200 Z"
        fill="#000000"
      />
    </svg>
  );
}

// Pre-measured values from mockup.png (per app-store-screenshots Skill SKILL.md)
const MK_W = 1022;
const MK_H = 2082;
const SC_L = (52 / MK_W) * 100;     // screen left %
const SC_T = (46 / MK_H) * 100;     // screen top %
const SC_W = (918 / MK_W) * 100;    // screen width %
const SC_H = (1990 / MK_H) * 100;   // screen height %
const SC_RX = (126 / 918) * 100;    // border-radius x %
const SC_RY = (126 / 1990) * 100;   // border-radius y %

function DeviceMockup({
  screenshot,
  scaleOverride,
}: {
  screenshot: string;
  scaleOverride?: number;
}) {
  const scale = scaleOverride ?? 1.15;
  const scaledW = MK_W * scale;
  const scaledH = MK_H * scale;

  return (
    <div
      style={{
        position: "relative",
        width: scaledW,
        height: scaledH,
        filter: "drop-shadow(0 40px 80px rgba(0,0,0,0.15))",
      }}
    >
      {/* Mockup frame on top */}
      <img
        src="/mockup.png"
        alt=""
        style={{
          display: "block",
          width: "100%",
          height: "100%",
        }}
        draggable={false}
      />
      {/* Screenshot inside frame — percentage-based positioning */}
      <div
        style={{
          position: "absolute",
          zIndex: 10,
          overflow: "hidden",
          left: `${SC_L}%`,
          top: `${SC_T}%`,
          width: `${SC_W}%`,
          height: `${SC_H}%`,
          borderRadius: `${SC_RX}% / ${SC_RY}%`,
        }}
      >
        <img
          src={screenshot}
          alt=""
          style={{
            display: "block",
            width: "100%",
            height: "100%",
            objectFit: "cover",
            objectPosition: "top",
          }}
          draggable={false}
        />
      </div>
    </div>
  );
}

function HeadlineBlock({
  headline,
  subline,
  headlineSize = 140,
  sublineSize = 64,
}: {
  headline: string;
  subline: string;
  headlineSize?: number;
  sublineSize?: number;
}) {
  return (
    <>
      <h1
        style={{
          fontSize: headlineSize,
          fontWeight: 800,
          lineHeight: 1.0,
          letterSpacing: "-0.025em",
          color: THEME.textPrimary,
          margin: 0,
          whiteSpace: "pre-line",
        }}
      >
        <MultilineText text={headline} />
      </h1>
      <p
        style={{
          fontSize: sublineSize,
          fontWeight: 400,
          lineHeight: 1.2,
          color: THEME.textSecondary,
          margin: "48px auto 0",
          maxWidth: 1050,
          whiteSpace: "pre-line",
        }}
      >
        <MultilineText text={subline} />
      </p>
    </>
  );
}

function SlideCanvas({ slide }: { slide: Slide }) {
  return (
    <div
      style={{
        width: CANVAS_W,
        height: CANVAS_H,
        position: "relative",
        overflow: "hidden",
        isolation: "isolate",
      }}
    >
      <Background variant={slide.bgVariant} />
      <AnalyticsPattern slideIdx={SCREEN_IDS.indexOf(slide.id as typeof SCREEN_IDS[number])} />

      {slide.layout === "headline-top" && (
        <>
          <div
            style={{
              position: "absolute",
              top: 220,
              left: 0,
              right: 0,
              padding: "0 100px",
              textAlign: "center",
              zIndex: 2,
            }}
          >
            <HeadlineBlock headline={slide.headline} subline={slide.subline} />
          </div>
          <div
            style={{
              position: "absolute",
              top: 880,
              left: "50%",
              transform: "translateX(-50%)",
              zIndex: 2,
            }}
          >
            <DeviceMockup screenshot={slide.screenshot} />
          </div>
        </>
      )}

      {/* Layout: brush-bg
          Pinselstrich-Balken dezent im Hintergrund (opacity niedrig), sonst
          wie headline-top: Claim oben zentriert, Mockup unten. Wiedererkennungs-
          motiv aus dem StatsFlow-Logo, reduziert und analytisch. */}
      {slide.layout === "brush-bg" && (
        <>
          <BrushStrokes
            opacity={0.06}
            rotation={-6}
            scale={1.1}
            top={-100}
            left={-150}
          />
          <div
            style={{
              position: "absolute",
              top: 220,
              left: 0,
              right: 0,
              padding: "0 100px",
              textAlign: "center",
              zIndex: 3,
            }}
          >
            <HeadlineBlock headline={slide.headline} subline={slide.subline} />
          </div>
          <div
            style={{
              position: "absolute",
              top: 880,
              left: "50%",
              transform: "translateX(-50%)",
              zIndex: 3,
            }}
          >
            <DeviceMockup screenshot={slide.screenshot} />
          </div>
        </>
      )}

      {/* Layout: mock-tilt
          Schräg gekipptes Mockup (links oder rechts, alternierend via idx),
          Text gegenüber oben. Dezenter Pinselstrich im Hintergrund.
          Alterniert: gerade idx → links gekippt, ungerade → rechts. */}
      {slide.layout === "mock-tilt" && (() => {
        const idx = SCREEN_IDS.indexOf(slide.id as typeof SCREEN_IDS[number]);
        const isLeft = idx % 2 === 1; // 02=left, 05=right, 09=left
        return (
          <>
            <BrushStrokes
              opacity={0.04}
              rotation={isLeft ? -12 : 12}
              scale={0.9}
              top={100}
              left={isLeft ? -300 : 400}
            />
            {/* Mockup übergroß, schräg, Kante ragt raus */}
            <div
              style={{
                position: "absolute",
                [isLeft ? "left" : "right"]: -280,
                top: 850,
                zIndex: 2,
                transform: `rotate(${isLeft ? -8 : 8}deg)`,
              }}
            >
              <DeviceMockup screenshot={slide.screenshot} scaleOverride={1.4} />
            </div>
            {/* Text gegenüber oben */}
            <div
              style={{
                position: "absolute",
                top: 200,
                [isLeft ? "right" : "left"]: 100,
                width: 1000,
                textAlign: isLeft ? "right" : "left",
                zIndex: 3,
              }}
            >
              <h1
                style={{
                  fontSize: 140,
                  fontWeight: 800,
                  lineHeight: 1.0,
                  letterSpacing: "-0.025em",
                  color: THEME.textPrimary,
                  margin: 0,
                }}
              >
                <MultilineText text={slide.headline} />
              </h1>
              <p
                style={{
                  fontSize: 64,
                  fontWeight: 400,
                  lineHeight: 1.2,
                  color: THEME.textSecondary,
                  margin: "40px 0 0 0",
                  maxWidth: 900,
                  whiteSpace: "pre-line",
                  marginLeft: isLeft ? "auto" : 0,
                }}
              >
                <MultilineText text={slide.subline} />
              </p>
            </div>
          </>
        );
      })()}

      {/* Layout: combo
          Notification-iPhone von oben reinragend (unteres Sechstel sichtbar =
          Lockscreen mit Notification). Widget-iPhone von unten reinragend
          (oberes Drittel sichtbar = Homescreen mit Widget). Text mittig.
          Hintergrund: helle BG mit dezenten Graph-/Balkendiagramm-Silhouetten. */}
      {slide.layout === "combo" && (
        <>
          {/* Notification-iPhone von oben — nur unteres Sechstel sichtbar */}
          <div
            style={{
              position: "absolute",
              top: -1650,
              left: "50%",
              transform: "translateX(-50%)",
              zIndex: 2,
            }}
          >
            <DeviceMockup screenshot={slide.screenshot} scaleOverride={1.15} />
          </div>

          {/* Text mittig */}
          <div
            style={{
              position: "absolute",
              top: 1050,
              left: 0,
              right: 0,
              padding: "0 100px",
              textAlign: "center",
              zIndex: 3,
            }}
          >
            <h1
              style={{
                fontSize: 140,
                fontWeight: 800,
                lineHeight: 1.0,
                letterSpacing: "-0.025em",
                color: THEME.textPrimary,
                margin: 0,
              }}
            >
              <MultilineText text={slide.headline} />
            </h1>
            <p
              style={{
                fontSize: 64,
                fontWeight: 400,
                lineHeight: 1.2,
                color: THEME.textSecondary,
                margin: "36px auto 0",
                maxWidth: 900,
                whiteSpace: "pre-line",
                textAlign: "center",
              }}
            >
              <MultilineText text={slide.subline} nowrap={false} />
            </p>
          </div>

          {/* Widget-iPhone von unten — oberes Drittel sichtbar */}
          {slide.screenshot2 && (
            <div
              style={{
                position: "absolute",
                bottom: -1400,
                left: "50%",
                transform: "translateX(-50%)",
                zIndex: 2,
              }}
            >
              <DeviceMockup screenshot={slide.screenshot2} scaleOverride={1.15} />
            </div>
          )}
        </>
      )}
    </div>
  );
}

export default function Home() {
  const refs = useRef<Record<string, HTMLDivElement | null>>({});
  const [busy, setBusy] = useState<string | null>(null);

  async function exportSlide(slide: Slide) {
    const key = `${slide.id}-${slide.locale}`;
    const el = refs.current[key];
    if (!el) return;
    setBusy(key);
    try {
      const dataUrl = await toPng(el, {
        pixelRatio: 1,
        cacheBust: true,
        width: CANVAS_W,
        height: CANVAS_H,
      });
      const a = document.createElement("a");
      a.href = dataUrl;
      a.download = `${slide.id}-${slide.locale}.png`;
      a.click();
    } finally {
      setBusy(null);
    }
  }

  return (
    <div style={{ padding: 40, background: "#0f172a", minHeight: "100vh" }}>
      <h1 style={{ color: "white", fontSize: 32, marginBottom: 24 }}>
        StatsFlow — App Store Screenshots (10 Screens × DE/EN)
      </h1>
      <p style={{ color: "#94a3b8", marginBottom: 32 }}>
        Chrome verwenden. Klicke „Export" unter einem Slide für 1320×2868 PNG.
        Source-Screenshots in public/screenshots/{"{de,en}"}/ ablegen.
      </p>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(2, 1fr)",
          gap: 40,
          gridAutoRows: "min-content",
        }}
      >
        {SLIDES.map((slide) => {
          const key = `${slide.id}-${slide.locale}`;
          return (
            <div key={key}>
              <div
                style={{
                  background: "#1e293b",
                  padding: 16,
                  borderRadius: 8,
                  marginBottom: 16,
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                }}
              >
                <span style={{ color: "white", fontWeight: 600 }}>
                  {slide.id} · {slide.locale.toUpperCase()}
                </span>
                <button
                  onClick={() => exportSlide(slide)}
                  disabled={busy === key}
                  style={{
                    background: busy === key ? "#475569" : "#000000",
                    color: "white",
                    border: "none",
                    padding: "10px 20px",
                    borderRadius: 6,
                    fontWeight: 600,
                    cursor: busy === key ? "wait" : "pointer",
                  }}
                >
                  {busy === key ? "Exportiere…" : "Export PNG"}
                </button>
              </div>
              <div
                style={{
                  width: CANVAS_W * 0.25,
                  height: CANVAS_H * 0.25,
                  overflow: "hidden",
                  background: "#0b1220",
                  borderRadius: 8,
                }}
              >
                <div
                  style={{
                    width: CANVAS_W,
                    height: CANVAS_H,
                    transform: "scale(0.25)",
                    transformOrigin: "top left",
                  }}
                >
                  <SlideCanvas slide={slide} />
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Hidden full-size render nodes — used ONLY for html-to-image export. */}
      <div
        aria-hidden
        style={{
          position: "fixed",
          left: "-100000px",
          top: 0,
          pointerEvents: "none",
        }}
      >
        {SLIDES.map((slide) => {
          const key = `${slide.id}-${slide.locale}`;
          return (
            <div
              key={`export-${key}`}
              ref={(el) => {
                refs.current[key] = el;
              }}
              style={{ width: CANVAS_W, height: CANVAS_H }}
            >
              <SlideCanvas slide={slide} />
            </div>
          );
        })}
      </div>
    </div>
  );
}
