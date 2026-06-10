#!/usr/bin/env python3
"""
Run a local LLM via MLX on Apple Silicon.
Usage:
  python3 run_mlx.py --task "Implement parseConfig from the spec above"
  python3 run_mlx.py --context-file spec.md --task "..." --output-file out.py
  python3 run_mlx.py --interactive
"""
import argparse
import sys


DEFAULT_MODEL = "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit"

DEFAULT_SYSTEM = (
    "You are a code-completion engine. Follow the spec exactly. "
    "Output only valid code. Do not explain. Do not use markdown fences."
)


def load_file(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def run(model: str, system: str, context: str, task: str, max_tokens: int) -> str:
    try:
        from mlx_lm import load, generate
    except ImportError:
        print("ERROR: mlx_lm not installed. Run: pip install mlx-lm", file=sys.stderr)
        sys.exit(1)

    print(f"Loading model: {model} ...", file=sys.stderr)
    llm, tokenizer = load(model)

    user_content = ""
    if context.strip():
        user_content += f"CONTEXT:\n{context.strip()}\n\n"
    user_content += f"TASK:\n{task.strip()}"

    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": user_content},
    ]

    if hasattr(tokenizer, "apply_chat_template"):
        prompt = tokenizer.apply_chat_template(
            messages, tokenize=False, add_generation_prompt=True
        )
    else:
        prompt = f"<s>[INST] {user_content} [/INST]"

    print("Running inference...", file=sys.stderr)
    output = generate(llm, tokenizer, prompt=prompt, max_tokens=max_tokens, verbose=False)
    return output


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
    parser = argparse.ArgumentParser(description="Run local LLM via MLX")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="MLX model ID from HuggingFace")
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
