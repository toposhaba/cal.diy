---
name: cursor-local-llm
description: >-
  Routes well-defined, pre-planned coding tasks to a local LLM (MLX on Apple Silicon,
  Foundry Local on Windows 11 24H2+). Use when the user has a plan, spec, or task
  breakdown and wants mechanical execution without a remote model — implement stubs,
  generate CRUD from a design, write tests for a defined API. Do not use for
  exploratory, architectural, or debugging work. Invoke when the user mentions
  local LLM, Foundry Local, MLX, or offloading mechanical implementation.
disable-model-invocation: true
---

# Cursor Local LLM

Executes well-defined, pre-planned coding tasks using a platform-native local LLM:

- **macOS (Apple Silicon)**: MLX via `mlx_lm`
- **Windows (11 24H2+)**: Microsoft Foundry Local

Run from project root: `c:\Users\incap\Documents\GitHub\cal.diy`

## Prerequisites

- Python 3.9+ (`python3` on macOS, `python` or `python3` on Windows)
- **macOS Apple Silicon**: `pip install mlx-lm`
- **Windows 11 24H2+**: Foundry Local (`winget install Microsoft.FoundryLocal`) and `pip install openai`
- See [references/setup.md](references/setup.md) for full install and troubleshooting

## When to use this skill

**Use it** when all of these are true:

1. A plan, spec, task list, or design doc already exists — decisions are made
2. The task is clearly scoped (inputs, outputs, and constraints are known)
3. The work is mechanical: filling stubs, generating boilerplate, implementing a defined interface, writing tests for a known API

**Do not use it** for:

- Exploratory work, debugging, architecture decisions
- Tasks requiring reasoning about tradeoffs
- Anything where the right answer is unclear without experimentation

## Step 1 — Detect platform and runtime

```powershell
python .cursor/skills/cursor-local-llm/scripts/detect_runtime.py
```

On macOS, use `python3` instead of `python` if needed.

Prints one of:

- `mlx` — macOS Apple Silicon with mlx_lm installed
- `mlx_missing` — macOS Apple Silicon but mlx_lm not installed
- `foundry` — Windows with Foundry Local installed
- `foundry_missing` — Windows but Foundry Local not installed
- `unsupported` — neither platform supported

Read [references/setup.md](references/setup.md) for install instructions.

## Step 2 — Prepare the prompt

A good local-LLM prompt for well-defined work has three parts:

```
SYSTEM: You are a code-completion engine. Follow the spec exactly.
        Output only valid {language} code. No explanation. No markdown fences.

CONTEXT: <paste the plan / spec / interface / types>

TASK: <single, concrete instruction — one function, one file, one transformation>
```

**Key rules:**

- One task per call — local models are small; don't ask for an entire module at once
- Be explicit about language, style, and output format
- Include relevant type signatures, interfaces, or schemas in CONTEXT
- If the spec has 10 functions, loop: call the model 10 times, once per function

Read [references/prompting.md](references/prompting.md) for patterns and examples.

## Step 3 — Run the local LLM

### macOS — MLX

```bash
python3 .cursor/skills/cursor-local-llm/scripts/run_mlx.py \
  --model mlx-community/Qwen2.5-Coder-7B-Instruct-4bit \
  --system-file system_prompt.txt \
  --context-file spec.md \
  --task "Implement the function parse_config from the spec above."
```

Interactive:

```bash
python3 .cursor/skills/cursor-local-llm/scripts/run_mlx.py --interactive
```

**Recommended models** (fast on M1/M2/M3, good at code):

- `mlx-community/Qwen2.5-Coder-7B-Instruct-4bit` — best all-round (default)
- `mlx-community/Qwen2.5-Coder-3B-Instruct-4bit` — faster, less RAM
- `mlx-community/DeepSeek-R1-0528-Qwen3-8B-4bit` — better reasoning, slower

Models auto-download on first use from Hugging Face (~4–8 GB).

### Windows — Foundry Local

```powershell
python .cursor/skills/cursor-local-llm/scripts/run_foundry.py `
  --model phi-4-mini `
  --system-file system_prompt.txt `
  --context-file spec.md `
  --task "Implement the function parse_config from the spec above."
```

Interactive:

```powershell
python .cursor/skills/cursor-local-llm/scripts/run_foundry.py --interactive
```

**Recommended models:**

- `phi-4-mini` — best all-round for code (default)
- `phi-3.5-mini-instruct` — lighter, faster

Install a model once:

```powershell
foundry model run phi-4-mini
```

Also requires: `pip install openai`

## Step 4 — Review and integrate

Local models make mechanical errors (wrong variable names, off-by-one, missing imports). Always:

1. Read the output before accepting it
2. Run tests or type-check if available
3. For multi-step tasks, feed each output back as context for the next call (see [references/chaining.md](references/chaining.md))

## Reference files

- [references/setup.md](references/setup.md) — Install instructions for MLX and Foundry Local
- [references/prompting.md](references/prompting.md) — Prompt patterns and worked examples
- [references/chaining.md](references/chaining.md) — Chaining multiple local calls for larger tasks
- [scripts/detect_runtime.py](scripts/detect_runtime.py) — Detects available runtime
- [scripts/run_mlx.py](scripts/run_mlx.py) — MLX runner
- [scripts/run_foundry.py](scripts/run_foundry.py) — Foundry Local runner
