#!/usr/bin/env bash
# setup.sh — one-time setup for tts.sh on a fresh WSL2 Ubuntu machine
#
# USAGE
#   ./setup.sh
#
# WHAT IT DOES
#   1. Installs pulseaudio-utils (paplay)
#   2. Installs piper-tts via pip
#   3. Downloads the Amy voice model
#   4. Wires up ~/.zshrc via tts.sh install

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VOICE_DIR="$HOME/.local/share/piper"
VOICE_MODEL="en_US-amy-medium"
VOICE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium"

echo ""
echo "  tts.sh setup"
echo "  WSL2 Ubuntu — Piper TTS"
echo ""

# ── 1. pulseaudio-utils ───────────────────────────────────────────────────────
echo "[1/4] Checking paplay..."
if command -v paplay >/dev/null 2>&1; then
    echo "  OK - paplay already installed"
else
    echo "  Installing pulseaudio-utils..."
    sudo apt-get install -y pulseaudio-utils
    echo "  OK - paplay installed"
fi

# ── 2. piper-tts ─────────────────────────────────────────────────────────────
echo "[2/4] Checking piper..."
if command -v piper >/dev/null 2>&1; then
    echo "  OK - piper already installed"
else
    echo "  Installing piper-tts via pip..."
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install piper-tts --quiet
    elif command -v pip >/dev/null 2>&1; then
        pip install piper-tts --quiet
    else
        echo "  ERROR: pip not found. Install Python 3 and pip first." >&2
        exit 1
    fi
    echo "  OK - piper installed"
fi

# ── 3. Voice model ────────────────────────────────────────────────────────────
echo "[3/4] Checking voice model ($VOICE_MODEL)..."
mkdir -p "$VOICE_DIR"

if [[ -f "$VOICE_DIR/$VOICE_MODEL.onnx" && -f "$VOICE_DIR/$VOICE_MODEL.onnx.json" ]]; then
    echo "  OK - voice model already downloaded"
else
    echo "  Downloading $VOICE_MODEL..."
    wget -q --show-progress -P "$VOICE_DIR" \
        "$VOICE_URL/$VOICE_MODEL.onnx" \
        "$VOICE_URL/$VOICE_MODEL.onnx.json"
    echo "  OK - voice model downloaded"
fi

# ── 4. Wire up ~/.zshrc ───────────────────────────────────────────────────────
echo "[4/4] Wiring up shell..."
bash "$SCRIPT_DIR/tts.sh" install

echo ""
echo "  Setup complete."
echo ""
echo "  Run:  source ~/.zshrc"
echo "  Then: tts.sh test"
echo ""
