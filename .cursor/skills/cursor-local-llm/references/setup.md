# Setup Guide

## macOS — MLX

### Requirements
- Apple Silicon Mac (M1 or later)
- macOS 13 Ventura or later
- Python 3.9–3.12 (`python3 --version`)
- ~8 GB free disk space per model

### Install
```bash
pip install mlx-lm
```

That's it. Models download automatically on first use.

### Verify
```bash
python3 -c "import mlx_lm; print('mlx_lm ready')"
```

### Troubleshooting
- **`pip` not found**: use `pip3` or `python3 -m pip`
- **`mlx` install fails**: requires macOS 13+; check with `sw_vers`
- **Slow first run**: the model is downloading (~4 GB); subsequent runs are instant
- **Out of memory**: switch to the 3B model: `mlx-community/Qwen2.5-Coder-3B-Instruct-4bit`

---

## Windows — Foundry Local

### Requirements
- Windows 11 version 24H2 (build 26100+) — check with `winver`
- NPU/GPU acceleration requires Copilot+ PC; CPU fallback works on any Win11 24H2
- ~5 GB free disk space per model

### Install
```powershell
winget install Microsoft.FoundryLocal
```

Then pull a model (one-time, ~2–5 GB download):
```powershell
foundry model run phi-4-mini
```

### Verify
```powershell
foundry model list
```

### Python client
```bash
pip install openai   # Foundry Local exposes an OpenAI-compatible API
```

### Troubleshooting
- **`winget` not found**: update Windows or install App Installer from the Microsoft Store
- **`foundry` not found after install**: restart your terminal
- **Model download hangs**: check disk space; models go to `%LOCALAPPDATA%\Microsoft\FoundryLocal`
- **CPU fallback is slow**: expected on non-Copilot+ hardware; use the smaller `phi-3.5-mini-instruct`
- **Windows 10 users**: Foundry Local requires Windows 11 24H2; use Ollama instead as a fallback

---

## Neither platform supported?

If `detect_runtime.py` returns `unsupported`, the user is likely on:
- Windows 10 or older Windows 11
- macOS on Intel

**Recommended fallback**: Ollama (`https://ollama.com`) — one installer, works everywhere, same OpenAI-compatible API. The `run_mlx.py` and `run_foundry.py` scripts can be pointed at Ollama by setting `--base-url http://localhost:11434/v1`.
