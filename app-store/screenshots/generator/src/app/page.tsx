"use client";

import { useRef, useState } from "react";
import { toPng } from "html-to-image";

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

type Layout = "headline-top" | "mock-left" | "mock-right";
type Locale = "de" | "en" | "fr";

type Slide = {
  id: string;
  locale: Locale;
  headline: string;
  subline: string;
  screenshot: string;
  layout: Layout;
  bgVariant: 0 | 1 | 2;
};

type Copy = {
  de: { headline: string; subline: string };
  en: { headline: string; subline: string };
  fr: { headline: string; subline: string };
};

const SCREEN_IDS = [
  "01-dashboard",
  "02-details",
  "03-realtime",
  "04-vergleich",
  "05-events",
  "06-widget",
  "07-account-switcher",
  "08-start",
] as const;

const COPY: Record<string, Copy> = {
  "01-dashboard": {
    de: { headline: "PLACEHOLDER_DE", subline: "PLACEHOLDER_DE_SUB" },
    en: { headline: "PLACEHOLDER_EN", subline: "PLACEHOLDER_EN_SUB" },
    fr: { headline: "PLACEHOLDER_FR", subline: "PLACEHOLDER_FR_SUB" },
  },
  "02-details": {
    de: { headline: "PLACEHOLDER_DE", subline: "PLACEHOLDER_DE_SUB" },
    en: { headline: "PLACEHOLDER_EN", subline: "PLACEHOLDER_EN_SUB" },
    fr: { headline: "PLACEHOLDER_FR", subline: "PLACEHOLDER_FR_SUB" },
  },
  "03-realtime": {
    de: { headline: "PLACEHOLDER_DE", subline: "PLACEHOLDER_DE_SUB" },
    en: { headline: "PLACEHOLDER_EN", subline: "PLACEHOLDER_EN_SUB" },
    fr: { headline: "PLACEHOLDER_FR", subline: "PLACEHOLDER_FR_SUB" },
  },
  "04-vergleich": {
    de: { headline: "PLACEHOLDER_DE", subline: "PLACEHOLDER_DE_SUB" },
    en: { headline: "PLACEHOLDER_EN", subline: "PLACEHOLDER_EN_SUB" },
    fr: { headline: "PLACEHOLDER_FR", subline: "PLACEHOLDER_FR_SUB" },
  },
  "05-events": {
    de: { headline: "PLACEHOLDER_DE", subline: "PLACEHOLDER_DE_SUB" },
    en: { headline: "PLACEHOLDER_EN", subline: "PLACEHOLDER_EN_SUB" },
    fr: { headline: "PLACEHOLDER_FR", subline: "PLACEHOLDER_FR_SUB" },
  },
  "06-widget": {
    de: { headline: "PLACEHOLDER_DE", subline: "PLACEHOLDER_DE_SUB" },
    en: { headline: "PLACEHOLDER_EN", subline: "PLACEHOLDER_EN_SUB" },
    fr: { headline: "PLACEHOLDER_FR", subline: "PLACEHOLDER_FR_SUB" },
  },
  "07-account-switcher": {
    de: { headline: "PLACEHOLDER_DE", subline: "PLACEHOLDER_DE_SUB" },
    en: { headline: "PLACEHOLDER_EN", subline: "PLACEHOLDER_EN_SUB" },
    fr: { headline: "PLACEHOLDER_FR", subline: "PLACEHOLDER_FR_SUB" },
  },
  "08-start": {
    de: { headline: "PLACEHOLDER_DE", subline: "PLACEHOLDER_DE_SUB" },
    en: { headline: "PLACEHOLDER_EN", subline: "PLACEHOLDER_EN_SUB" },
    fr: { headline: "PLACEHOLDER_FR", subline: "PLACEHOLDER_FR_SUB" },
  },
};

const LAYOUT_ROTATION: Layout[] = [
  "headline-top", // 01 Dashboard
  "mock-left",    // 02 Details
  "mock-right",   // 03 Realtime
  "headline-top", // 04 Vergleich
  "mock-left",    // 05 Events
  "mock-right",   // 06 Widget
  "headline-top", // 07 Account Switcher
  "mock-left",    // 08 Start Screen
];

function sourcePath(id: string, locale: Locale): string {
  const num = id.slice(0, 2);
  const name = id.slice(3);
  return `/screenshots/${locale}/${num}-${name}.png`;
}

const SLIDES: Slide[] = SCREEN_IDS.flatMap((id, idx) =>
  (["de", "en", "fr"] as const).map((locale) => ({
    id,
    locale,
    headline: COPY[id][locale].headline,
    subline: COPY[id][locale].subline,
    screenshot: sourcePath(id, locale),
    layout: LAYOUT_ROTATION[idx],
    bgVariant: (idx % 3) as 0 | 1 | 2,
  }))
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

function DeviceMockup({
  screenshot,
  scaleOverride,
}: {
  screenshot: string;
  scaleOverride?: number;
}) {
  const mockupW = 1022;
  const mockupH = 2082;
  const scale = scaleOverride ?? 1.15;
  const scaledW = mockupW * scale;
  const scaledH = mockupH * scale;

  const screenInsetX = scaledW * 0.041;
  const screenInsetY = scaledH * 0.027;
  const screenW = scaledW - screenInsetX * 2;
  const screenH = scaledH - screenInsetY * 2;

  return (
    <div
      style={{
        position: "relative",
        width: scaledW,
        height: scaledH,
        filter: "drop-shadow(0 40px 80px rgba(0,0,0,0.15))",
      }}
    >
      <div
        style={{
          position: "absolute",
          left: screenInsetX,
          top: screenInsetY,
          width: screenW,
          height: screenH,
          borderRadius: 72,
          overflow: "hidden",
        }}
      >
        <img
          src={screenshot}
          alt=""
          style={{
            width: "100%",
            height: "100%",
            objectFit: "cover",
            display: "block",
          }}
        />
      </div>
      <img
        src="/mockup.png"
        alt=""
        style={{
          position: "absolute",
          inset: 0,
          width: "100%",
          height: "100%",
          pointerEvents: "none",
        }}
      />
    </div>
  );
}

function HeadlineBlock({
  headline,
  subline,
  headlineSize = 150,
  sublineSize = 76,
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
          maxWidth: 1150,
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

      {slide.layout === "mock-left" && (
        <>
          <div
            style={{
              position: "absolute",
              left: -360,
              top: 900,
              zIndex: 2,
              transform: "rotate(-8deg)",
            }}
          >
            <DeviceMockup screenshot={slide.screenshot} scaleOverride={1.45} />
          </div>
          <div
            style={{
              position: "absolute",
              top: 200,
              right: 100,
              width: 1050,
              textAlign: "right",
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
                fontSize: 68,
                fontWeight: 400,
                lineHeight: 1.2,
                color: THEME.textSecondary,
                margin: "40px 0 0 0",
                whiteSpace: "pre-line",
              }}
            >
              <MultilineText text={slide.subline} />
            </p>
          </div>
        </>
      )}

      {slide.layout === "mock-right" && (
        <>
          <div
            style={{
              position: "absolute",
              right: -360,
              top: 900,
              zIndex: 2,
              transform: "rotate(8deg)",
            }}
          >
            <DeviceMockup screenshot={slide.screenshot} scaleOverride={1.45} />
          </div>
          <div
            style={{
              position: "absolute",
              top: 200,
              left: 100,
              width: 1050,
              textAlign: "left",
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
                fontSize: 68,
                fontWeight: 400,
                lineHeight: 1.2,
                color: THEME.textSecondary,
                margin: "40px 0 0 0",
                whiteSpace: "pre-line",
              }}
            >
              <MultilineText text={slide.subline} />
            </p>
          </div>
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
        StatFlow — App Store Screenshots (8 Screens × DE/EN/FR)
      </h1>
      <p style={{ color: "#94a3b8", marginBottom: 32 }}>
        Chrome verwenden. Klicke „Export" unter einem Slide für 1320×2868 PNG.
        Source-Screenshots in public/screenshots/{"{de,en,fr}"}/ ablegen.
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
