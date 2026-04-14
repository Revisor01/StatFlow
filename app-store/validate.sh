#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-quick}"
EXPORT_BASE="app-store/screenshots/export"
PASS=0
FAIL=0
ERRORS=()

# --- Assertion helpers ---

assert_file_exists() {
  local path="$1"
  if [ -f "$path" ]; then
    echo "  ✓ $path"
    PASS=$((PASS+1))
  else
    echo "  ✗ MISSING: $path"
    ERRORS+=("MISSING: $path")
    FAIL=$((FAIL+1))
  fi
}

assert_dir_exists() {
  local path="$1"
  if [ -d "$path" ]; then
    echo "  ✓ dir: $path"
    PASS=$((PASS+1))
  else
    echo "  ✗ MISSING dir: $path"
    ERRORS+=("MISSING dir: $path")
    FAIL=$((FAIL+1))
  fi
}

assert_image_dim() {
  local path="$1"
  local expected_w="$2"
  local expected_h="$3"
  if [ ! -f "$path" ]; then
    echo "  ✗ FILE NOT FOUND: $path"
    ERRORS+=("FILE NOT FOUND: $path")
    FAIL=$((FAIL+1))
    return
  fi
  local w h
  w=$(sips -g pixelWidth "$path" 2>/dev/null | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$path" 2>/dev/null | awk '/pixelHeight/{print $2}')
  if [ "$w" = "$expected_w" ] && [ "$h" = "$expected_h" ]; then
    echo "  ✓ ${path}: ${w}×${h}"
    PASS=$((PASS+1))
  else
    echo "  ✗ WRONG DIM: ${path} got ${w}×${h}, expected ${expected_w}×${expected_h}"
    ERRORS+=("WRONG DIM: $path got ${w}x${h}, expected ${expected_w}x${expected_h}")
    FAIL=$((FAIL+1))
  fi
}

assert_json_field() {
  local file="$1"
  local jq_path="$2"
  local expected="$3"
  if [ ! -f "$file" ]; then
    echo "  ✗ FILE NOT FOUND: $file"
    ERRORS+=("FILE NOT FOUND: $file")
    FAIL=$((FAIL+1))
    return
  fi
  local actual
  actual=$(jq -r "$jq_path" "$file" 2>/dev/null || echo "JQ_ERROR")
  if [ "$actual" = "$expected" ]; then
    echo "  ✓ ${file}[${jq_path}] = ${actual}"
    PASS=$((PASS+1))
  else
    echo "  ✗ WRONG VALUE: ${file}[${jq_path}] = '${actual}', expected '${expected}'"
    ERRORS+=("WRONG VALUE: $file[$jq_path] = '$actual', expected '$expected'")
    FAIL=$((FAIL+1))
  fi
}

# --- Quick mode: structure checks ---

echo ""
echo "=== validate.sh — Phase 23 (mode: $MODE) ==="
echo ""
echo "--- Directory structure ---"
assert_dir_exists "app-store/screenshots/source/de"
assert_dir_exists "app-store/screenshots/source/en"
assert_dir_exists "app-store/screenshots/export/de"
assert_dir_exists "app-store/screenshots/export/en"
assert_dir_exists "app-store/submission"

echo ""
echo "--- Generator ---"
assert_file_exists "app-store/screenshots/generator/src/app/page.tsx"
assert_file_exists "app-store/screenshots/generator/src/app/layout.tsx"
assert_file_exists "app-store/screenshots/generator/public/mockup.png"

echo ""
echo "--- Export PNG count (expected 16: 8 slides × 2 locales) ---"
DE_COUNT=$(ls "${EXPORT_BASE}/de/"*.png 2>/dev/null | wc -l | tr -d ' ' || true)
EN_COUNT=$(ls "${EXPORT_BASE}/en/"*.png 2>/dev/null | wc -l | tr -d ' ' || true)
DE_COUNT=${DE_COUNT:-0}
EN_COUNT=${EN_COUNT:-0}
echo "  DE: ${DE_COUNT}/8  EN: ${EN_COUNT}/8"
TOTAL=$((DE_COUNT + EN_COUNT))
if [ "$TOTAL" -eq 16 ]; then
  echo "  ✓ 16 PNGs gesamt vorhanden"
  PASS=$((PASS+1))
else
  echo "  ⚠ Erst ${TOTAL}/16 PNGs vorhanden (OK bis Export abgeschlossen)"
fi

echo ""
echo "--- Submission script ---"
assert_file_exists "app-store/submission/submit.ts"
assert_file_exists "app-store/submission/lib/jwt.ts"
assert_file_exists "app-store/submission/lib/asc-api.ts"
assert_file_exists "app-store/submission/lib/config.ts"

if [ "$MODE" = "full" ]; then
  echo ""
  echo "--- Full mode: PNG dimension checks (1320×2868) ---"
  SLIDES=(
    "01-dashboard" "02-details" "03-realtime" "04-vergleich"
    "05-events" "06-widget" "07-account-switcher" "08-start"
  )
  for locale in de en; do
    for slide in "${SLIDES[@]}"; do
      PNG="${EXPORT_BASE}/${locale}/${slide}-${locale}.png"
      if [ -f "$PNG" ]; then
        assert_image_dim "$PNG" 1320 2868
      fi
    done
  done

  echo ""
  echo "--- TypeScript type checks ---"
  if [ -f "app-store/screenshots/generator/tsconfig.json" ]; then
    echo "  Running: npx tsc --noEmit (generator)"
    cd app-store/screenshots/generator && npx tsc --noEmit 2>&1 && echo "  ✓ generator: no TS errors" || { echo "  ✗ generator: TS errors"; ERRORS+=("generator: TS errors"); FAIL=$((FAIL+1)); }; cd ../../..
  fi
  if [ -f "app-store/submission/tsconfig.json" ]; then
    echo "  Running: npx tsc --noEmit (submission)"
    cd app-store/submission && npx tsc --noEmit 2>&1 && echo "  ✓ submission: no TS errors" || { echo "  ✗ submission: TS errors"; ERRORS+=("submission: TS errors"); FAIL=$((FAIL+1)); }; cd ../..
  fi
fi

echo ""
echo "=== Result: ${PASS} passed, ${FAIL} failed ==="
if [ "${#ERRORS[@]}" -gt 0 ]; then
  echo ""
  echo "Failures:"
  for e in "${ERRORS[@]}"; do echo "  - $e"; done
  exit 1
fi
echo "All checks passed."
