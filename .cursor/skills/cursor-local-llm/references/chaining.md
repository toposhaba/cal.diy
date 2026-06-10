# Chaining Local LLM Calls

When a spec has multiple deliverables, run the model once per unit and chain outputs forward.
Local models have limited context — chaining keeps each call focused and small.

---

## Basic Pattern

```
for each task_unit in spec:
    context = base_spec + previously_generated_code
    output  = run_local_llm(context, task_unit)
    append output to generated_code
    review output before proceeding
```

**Always review between steps.** A bad output in step 2 corrupts everything after it.

---

## Worked Example — Implementing a 5-function module

Given a spec with functions: `parseConfig`, `validateConfig`, `mergeConfigs`, `loadFromFile`, `saveToFile`

**Call 1:**
```
CONTEXT: [spec]
TASK: Implement parseConfig
```
→ Review output. Fix if needed. Save as `generated.ts`.

**Call 2:**
```
CONTEXT: [spec] + [parseConfig output]
TASK: Implement validateConfig — it calls parseConfig internally
```
→ Review. Append to `generated.ts`.

**Call 3:**
```
CONTEXT: [spec] + [parseConfig] + [validateConfig]
TASK: Implement mergeConfigs
```
...and so on.

---

## Context Budget

Small models (3B–8B) handle roughly:
- **4K–8K tokens** of context comfortably
- ~300 lines of code + prompt overhead safely

If your accumulated output exceeds ~200 lines, trim the context:
- Keep the spec/interface (always needed)
- Keep only the functions the current task calls
- Drop functions that are unrelated to the next task

---

## Scripts

`run_mlx.py` and `run_foundry.py` both accept `--context-file` which you can overwrite between calls:

**macOS:**

```bash
python3 .cursor/skills/cursor-local-llm/scripts/run_mlx.py \
  --context-file spec.md \
  --task "Implement parseConfig" \
  --output-file step1.ts

cat spec.md step1.ts > context2.md
python3 .cursor/skills/cursor-local-llm/scripts/run_mlx.py \
  --context-file context2.md \
  --task "Implement validateConfig (it calls parseConfig)" \
  --output-file step2.ts
```

**Windows:**

```powershell
python .cursor/skills/cursor-local-llm/scripts/run_foundry.py `
  --context-file spec.md `
  --task "Implement parseConfig" `
  --output-file step1.ts

Get-Content spec.md, step1.ts | Set-Content context2.md
python .cursor/skills/cursor-local-llm/scripts/run_foundry.py `
  --context-file context2.md `
  --task "Implement validateConfig (it calls parseConfig)" `
  --output-file step2.ts
```

---

## When chaining breaks down

If the model starts contradicting earlier outputs or ignoring the spec, stop and:
1. Trim the context (it may be overloaded)
2. Restate the interface/types explicitly in the next CONTEXT
3. If more than ~3 functions are going wrong, the task may not be well-defined enough — switch to a remote model for the design pass first
