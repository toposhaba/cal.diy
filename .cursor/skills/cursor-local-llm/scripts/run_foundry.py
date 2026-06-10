#!/usr/bin/env python3
"""
Run a local LLM via Microsoft Foundry Local on Windows.
Foundry Local exposes an OpenAI-compatible API at http://localhost:5273/v1

Usage:
  python scripts/run_foundry.py --task "Implement parseConfig from the spec above"
  python scripts/run_foundry.py --context-file spec.md --task "..." --output-file out.py
  python scripts/run_foundry.py --interactive
"""
import argparse
import subprocess
import sys
import time


DEFAULT_MODEL = "phi-4-mini"
FOUNDRY_BASE_URL = "http://localhost:5273/v1"
FOUNDRY_API_KEY = "foundry"   # Foundry Local accepts any non-empty key

DEFAULT_SYSTEM = (
    "You are a code-completion engine. Follow the spec exactly. "
    "Output only valid code. Do not explain. Do not use markdown fences."
)


def load_file(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def ensure_foundry_running(model: str):
    """Start Foundry Local service if not already running."""
    try:
        import urllib.request
        urllib.request.urlopen(f"{FOUNDRY_BASE_URL}/models", timeout=2)
        return  # already running
    except Exception:
        pass

    print(f"Starting Foundry Local with model {model}...", file=sys.stderr)
    subprocess.Popen(
        ["foundry", "service", "start"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    # Wait for service to be ready
    for _ in range(30):
        time.sleep(1)
        try:
            import urllib.request
            urllib.request.urlopen(f"{FOUNDRY_BASE_URL}/models", timeout=2)
            print("Foundry Local ready.", file=sys.stderr)
            return
        except Exception:
            pass
    print("WARNING: Foundry Local may not have started. Proceeding anyway.", file=sys.stderr)


def run(model: str, system: str, context: str, task: str, max_tokens: int) -> str:
    try:
        from openai import OpenAI
    except ImportError:
        print("ERROR: openai package not installed. Run: pip install openai", file=sys.stderr)
        sys.exit(1)

    ensure_foundry_running(model)

    client = OpenAI(base_url=FOUNDRY_BASE_URL, api_key=FOUNDRY_API_KEY)

    user_content = ""
    if context.strip():
        user_content += f"CONTEXT:\n{context.strip()}\n\n"
    user_content += f"TASK:\n{task.strip()}"

    print(f"Running inference with {model}...", file=sys.stderr)
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user_content},
        ],
        max_tokens=max_tokens,
        temperature=0.1,   # low temp for deterministic code generation
    )
    return response.choices[0].message.content or ""


def interactive_mode(model: str, system: str, max_tokens: int):
    print(f"Interactive mode — model: {model}")
    print("Enter CONTEXT (blank line to finish), then TASK.\n")

    print("CONTEXT (end with a blank line):")
    context_lines = []
    while True:
        line = input()
        if line == "":
            break
        context_lines.append(line)
    context = "\n".join(context_lines)

    print("\nTASK:")
    task = input()

    output = run(model, system, context, task, max_tokens)
    print("\n--- OUTPUT ---")
    print(output)


def main():
    parser = argparse.ArgumentParser(description="Run local LLM via Foundry Local")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Foundry Local model name")
    parser.add_argument("--system", default=DEFAULT_SYSTEM, help="System prompt text")
    parser.add_argument("--system-file", help="Path to system prompt file (overrides --system)")
    parser.add_argument("--context", default="", help="Context/spec text")
    parser.add_argument("--context-file", help="Path to context file (overrides --context)")
    parser.add_argument("--task", help="The task instruction")
    parser.add_argument("--output-file", help="Write output to this file instead of stdout")
    parser.add_argument("--max-tokens", type=int, default=1024)
    parser.add_argument("--interactive", action="store_true", help="Interactive input mode")
    args = parser.parse_args()

    system = load_file(args.system_file) if args.system_file else args.system
    context = load_file(args.context_file) if args.context_file else args.context

    if args.interactive:
        interactive_mode(args.model, system, args.max_tokens)
        return

    if not args.task:
        parser.error("--task is required (or use --interactive)")

    output = run(args.model, system, context, args.task, args.max_tokens)

    if args.output_file:
        with open(args.output_file, "w", encoding="utf-8") as f:
            f.write(output)
        print(f"Output written to {args.output_file}", file=sys.stderr)
    else:
        print(output)


if __name__ == "__main__":
    main()
