# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Meshing Around** is a feature-rich Python bot for the [Meshtastic](https://meshtastic.org/) mesh networking platform. It provides 150+ text-based commands for network testing, messaging, games, AI integration, emergency alerts, asset tracking, and more — all delivered via mesh radio messages.

## Development Commands

```bash
# Run the full-featured bot
python3 mesh_bot.py

# Run the lightweight variant
python3 pong_bot.py

# Run via launch script (handles venv activation)
./launch.sh bot        # mesh_bot.py
./launch.sh pong       # pong_bot.py
./launch.sh report     # HTML report generation

# Install/setup (Linux/RPi)
./install.sh

# Update from upstream
./update.sh

# Docker
docker compose up

# Run the test suite
python3 modules/test_bot.py

# Offline mesh simulator for testing without hardware
python3 etc/simulator.py
```

## Architecture

### Entry Points
- `mesh_bot.py` — Main bot (~2,600 lines), ~150+ commands
- `pong_bot.py` — Lightweight variant with core commands only

### Message Flow
```
Meshtastic Hardware (serial/TCP/BLE)
  → pubsub subscription
  → system.messageTrap()        # command detection & routing
  → auto_response()             # command dispatch dict in mesh_bot.py
  → handler functions           # handle_ping(), handle_bbspost(), etc.
  → response chunked (160 chars max)
  → interface.sendText()
```

### Key Modules (`modules/`)
- `system.py` — Command registration, message trapping, interface management, multi-radio support
- `settings.py` — Config parsing (`config.ini`) and global state
- `locationdata.py` — GPS tracking, proximity alerts, geofencing, CSV logging
- `inventory.py` — Asset tracking, check-in/checkout, POS system
- `bbstools.py` — Bulletin board system
- `llm.py` — Ollama/OpenWebUI LLM integration
- `radio.py` — Hamlib, WSJT-X, JS8Call, TTS integration
- `scheduler.py` — Message scheduling automation
- `filemon.py` — File monitoring and shell command execution
- `games/` — 16 game implementations (blackjack, dopewars, hangman, battleship, etc.)

### Configuration
Copy `config.template` to `config.ini` before running. Key sections:
- `[interface]` — Serial/TCP/BLE connection (supports up to 9 simultaneous interfaces)
- `[general]` — Response modes, channels, command behavior
- `[bbs]`, `[location]`, `[radioMon]`, `[llm]`, `[wx]`, etc. — Feature-specific settings

Config files (`config.ini`, `config_new.ini`) and data files (`.pkl`, `.csv`, `.db`, `.json`) are gitignored. `modules/custom_scheduler.py` is also gitignored (site-specific).

### Multi-Interface Pattern
Up to 9 simultaneous radio interfaces, each on its own thread. All messages converge in the single `auto_response()` handler. Interface index is tracked per-message for correct reply routing.

### Adding a New Command
1. Write a handler function in `mesh_bot.py` (e.g., `handle_myfeature()`)
2. Register it in `auto_response()` command dispatch dict
3. Add it to `system.py` trap_list for message detection
4. Add entry to help text

### State Persistence
Game state, BBS messages, and inventory data are stored as pickle files in `data/`. These are loaded at startup and saved on mutation.

## Deployment

**Systemd** (via `install.sh`): Installs `mesh_bot.service`, `pong_bot.service`, and optional reporting timer.

**Docker** (`compose.yaml`): Includes meshtasticd daemon, optional Ollama LLM server, test-bot, and debug console. Image auto-builds via `.github/workflows/docker-image.yml` on push.

## Utilities

- `script/configMerge.py` — Smart config.ini merging (used by `update.sh`)
- `script/injectDM.py` — Test DM injection without hardware
- `etc/simulator.py` — Offline mesh simulator
- `etc/report_generator5.py` — HTML5 dashboard generation
- `etc/db_admin.py` — Database administration
