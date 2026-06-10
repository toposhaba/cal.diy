#!/usr/bin/env python3
"""
Detects which local LLM runtime is available on this machine.
Prints one of: mlx | mlx_missing | foundry | foundry_missing | unsupported
"""
import platform
import subprocess
import sys


def is_apple_silicon() -> bool:
    return platform.system() == "Darwin" and platform.machine() == "arm64"


def is_windows() -> bool:
    return platform.system() == "Windows"


def mlx_installed() -> bool:
    try:
        import importlib.util
        return importlib.util.find_spec("mlx_lm") is not None
    except Exception:
        return False


def foundry_installed() -> bool:
    try:
        result = subprocess.run(
            ["foundry", "--version"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def main():
    if is_apple_silicon():
        if mlx_installed():
            print("mlx")
        else:
            print("mlx_missing")
            print(
                "\nMLX not installed. Run:\n  pip install mlx-lm",
                file=sys.stderr,
            )
    elif is_windows():
        if foundry_installed():
            print("foundry")
        else:
            print("foundry_missing")
            print(
                "\nFoundry Local not installed. Run:\n"
                "  winget install Microsoft.FoundryLocal\n"
                "  foundry model run phi-4-mini",
                file=sys.stderr,
            )
    else:
        print("unsupported")
        print(
            "\nNeither MLX (macOS Apple Silicon) nor Foundry Local (Windows 11 24H2+) "
            "is supported on this platform.\n"
            "Fallback: install Ollama from https://ollama.com",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
