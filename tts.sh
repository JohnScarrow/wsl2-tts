#!/usr/bin/env bash
# tts.sh — Piper TTS utilities for WSL2
#
# USAGE
#   source tts.sh               load say() into current shell
#   ./tts.sh watch              start buffered watcher (reads /tmp/tts-queue.txt)
#   ./tts.sh watch <file>       watch a custom queue file
#   ./tts.sh install            wire up ~/.zshrc on a new machine
#   ./tts.sh test               smoke-test the audio pipeline
#
# FROM OTHER TERMINALS (once watcher is running)
#   echo "build done"            >> /tmp/tts-queue.txt
#   make 2>&1 | tail -1          >> /tmp/tts-queue.txt

# ── Config (override with env vars) ──────────────────────────────────────────
PIPER_MODEL="${PIPER_MODEL:-$HOME/.local/share/piper/en_US-amy-medium.onnx}"
PIPER_SPEED="${PIPER_SPEED:-0.75}"
PIPER_SAMPLE_RATE=22050
TTS_QUEUE="${TTS_QUEUE:-/tmp/tts-queue.txt}"

# ── loud() ───────────────────────────────────────────────────────────────────
# Alias for the Claude Code watcher: just run `loud` in a dedicated terminal tab.
loud() { _tts_claude; }

# ── say() ─────────────────────────────────────────────────────────────────────
# say "some text"   or   echo "some text" | say
say() {
    local text="${*:-$(cat)}"
    [[ -z "$text" ]] && return
    echo "$text" | piper \
        --model "$PIPER_MODEL" \
        --length-scale "$PIPER_SPEED" \
        --output-raw 2>/dev/null | \
        paplay --raw --rate=$PIPER_SAMPLE_RATE --format=s16le --channels=1
}

# ── Buffered watcher ──────────────────────────────────────────────────────────
# Double-buffer: synthesises line N+1 while line N is playing, minimising gaps.
_tts_watch() {
    local queue_file="${1:-$TTS_QUEUE}"

    if ! command -v piper >/dev/null 2>&1; then
        echo "[tts] error: piper not found in PATH" >&2
        return 1
    fi
    if [[ ! -f "$PIPER_MODEL" ]]; then
        echo "[tts] error: model not found: $PIPER_MODEL" >&2
        return 1
    fi

    touch "$queue_file"
    echo "[tts] watching $queue_file  (Ctrl-C to stop)"

    local wav_a wav_b
    wav_a=$(mktemp /tmp/tts-a-XXXXXX.wav)
    wav_b=$(mktemp /tmp/tts-b-XXXXXX.wav)
    trap "rm -f '$wav_a' '$wav_b'; echo '[tts] stopped'" EXIT INT TERM

    local play_pid=""
    local current=$wav_a
    local next=$wav_b
    local tmp

    tail -n 0 -f "$queue_file" | while IFS= read -r line; do
        [[ -z "${line// }" ]] && continue

        # Synthesise into the next buffer while previous line may still play
        echo "$line" | piper \
            --model "$PIPER_MODEL" \
            --length-scale "$PIPER_SPEED" \
            --output-file "$next" 2>/dev/null

        # Wait for previous playback before swapping in the new audio
        [[ -n "$play_pid" ]] && wait "$play_pid" 2>/dev/null

        # Swap buffers and start playing in background
        tmp=$current; current=$next; next=$tmp
        paplay "$current" &
        play_pid=$!

    done

    [[ -n "$play_pid" ]] && wait "$play_pid" 2>/dev/null
}

# ── Claude Code watcher ───────────────────────────────────────────────────────
# Watches the active Claude Code session JSONL and speaks assistant text replies.
# Automatically follows new session files as they are created.
_tts_claude() {
    local projects_dir="$HOME/.claude/projects"

    if [[ ! -d "$projects_dir" ]]; then
        echo "[tts] error: $projects_dir not found — is Claude Code installed?" >&2
        return 1
    fi

    # Python snippet: tail a JSONL file, extract assistant text content
    local py='
import sys, json, subprocess, os, time, glob

def latest_jsonl(projects_dir):
    files = glob.glob(projects_dir + "/**/*.jsonl", recursive=True)
    return max(files, key=os.path.getmtime) if files else None

def extract_text(line):
    try:
        obj = json.loads(line)
        if obj.get("type") != "assistant":
            return None
        content = obj.get("message", {}).get("content", [])
        parts = [c["text"] for c in content if c.get("type") == "text" and c.get("text","").strip()]
        return " ".join(parts) if parts else None
    except Exception:
        return None

def speak(text, model, speed, rate):
    proc = subprocess.Popen(
        ["piper", "--model", model, "--length-scale", speed, "--output-raw"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
    )
    wav, _ = proc.communicate(text.encode())
    subprocess.run(
        ["paplay", "--raw", "--rate=" + rate, "--format=s16le", "--channels=1"],
        input=wav
    )

projects_dir = sys.argv[1]
model        = sys.argv[2]
speed        = sys.argv[3]
rate         = sys.argv[4]

current_file = None
fh = None

print("[tts] waiting for Claude Code session...", flush=True)

while True:
    latest = latest_jsonl(projects_dir)
    if latest != current_file:
        if fh:
            fh.close()
        current_file = latest
        if current_file:
            print(f"[tts] watching {current_file}", flush=True)
            fh = open(current_file)
            fh.seek(0, 2)  # seek to end
        else:
            time.sleep(2)
            continue

    line = fh.readline()
    if not line:
        # Check if a newer file has appeared
        time.sleep(0.2)
        continue

    text = extract_text(line.strip())
    if text:
        suffix = "..." if len(text) > 60 else ""
        print("[tts] speaking: " + text[:60] + suffix, flush=True)
        speak(text, model, speed, rate)
'

    echo "[tts] Claude Code TTS active  (Ctrl-C to stop)"
    python3 - "$projects_dir" "$PIPER_MODEL" "$PIPER_SPEED" "$PIPER_SAMPLE_RATE" <<< "$py"
}

# ── install ───────────────────────────────────────────────────────────────────
# Run once on a new machine after cloning the repo.
# Optional argument: path to shell rc file (default: ~/.zshrc)
_tts_install() {
    local script_path
    script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    local rc="${1:-$HOME/.zshrc}"
    local marker="# tts.sh"

    if ! grep -q "PULSE_SERVER" "$rc" 2>/dev/null; then
        echo 'export PULSE_SERVER=unix:/mnt/wslg/PulseServer' >> "$rc"
        echo "[tts] added PULSE_SERVER to $rc"
    else
        echo "[tts] PULSE_SERVER already in $rc"
    fi

    if ! grep -q "$marker" "$rc" 2>/dev/null; then
        printf '\n%s\nsource "%s"\n' "$marker" "$script_path" >> "$rc"
        echo "[tts] added source line to $rc"
        echo "[tts] run: source $rc"
    else
        echo "[tts] already installed in $rc"
    fi
}

# ── Entry point ───────────────────────────────────────────────────────────────
# When sourced: functions are loaded, nothing runs.
# When executed directly: handle subcommands.
#
# Source detection works differently in bash vs zsh:
#   bash: BASH_SOURCE[0] != $0 means sourced
#   zsh:  $0 is "-zsh" or "zsh" when sourced interactively
_tts_is_direct() {
    if [[ -n "${BASH_VERSION:-}" ]]; then
        [[ "${BASH_SOURCE[0]}" == "$0" ]]
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        # ZSH_EVAL_CONTEXT is "toplevel:file" when sourced, "toplevel" when run directly
        [[ ! "$ZSH_EVAL_CONTEXT" =~ ":file" ]]
    else
        false
    fi
}

if _tts_is_direct; then
    case "${1:-}" in
        watch)   _tts_watch "${2:-}" ;;
        claude)  _tts_claude ;;
        install) _tts_install "${2:-}" ;;
        test)    say "TTS is working correctly." ;;
        *)
            echo "Usage: $(basename "$0") watch [file] | claude | install | test"
            ;;
    esac
fi
unset -f _tts_is_direct 2>/dev/null || true
