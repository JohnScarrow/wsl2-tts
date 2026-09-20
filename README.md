# wsl2-tts

Piper TTS utilities for WSL2 Ubuntu. Provides a `say` command, a buffered file watcher, and automatic text-to-speech for Claude Code sessions.

## Requirements

- WSL2 Ubuntu with WSLg (Windows 11)
- Python 3.8+
- pip

## Installation

Clone the repo and run the setup script for your shell:

```bash
git clone https://github.com/JohnScarrow/wsl2-tts.git
cd wsl2-tts
./setup.sh        # zsh
./setup_bash.sh   # bash
source ~/.zshrc   # or source ~/.bashrc
```

Then verify everything works:

```bash
tts.sh test
```

## Usage

### `say` — speak text immediately

```bash
say "hello world"
echo "build finished" | say
```

### `loud` — Claude Code TTS watcher

Run in a dedicated terminal tab. Automatically speaks Claude Code responses as they arrive — no extra commands needed in your Claude terminal.

```bash
loud
```

### `tts.sh watch` — general purpose watcher

Run in a dedicated terminal tab. Speaks any line appended to the queue file.

```bash
tts.sh watch                  # watches /tmp/tts-queue.txt
tts.sh watch /tmp/myfile.txt  # watches a custom file
```

From any other terminal:

```bash
echo "build done"   >> /tmp/tts-queue.txt
make 2>&1 | tail -1 >> /tmp/tts-queue.txt
```

## Configuration

Override defaults with environment variables:

| Variable | Default | Description |
|---|---|---|
| `PIPER_MODEL` | `~/.local/share/piper/en_US-amy-medium.onnx` | Voice model path |
| `PIPER_SPEED` | `0.75` | Speaking rate (lower = faster) |
| `TTS_QUEUE` | `/tmp/tts-queue.txt` | Queue file for `tts.sh watch` |

## Voice Models

Additional voices are available at [rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices). Download the `.onnx` and `.onnx.json` files to `~/.local/share/piper/` and update `PIPER_MODEL` in `tts.sh`.
