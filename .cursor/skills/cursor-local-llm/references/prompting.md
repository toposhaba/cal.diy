# Prompting Guide for Well-Defined Tasks

Local models are small. They work well when the prompt does the thinking for them.
The goal: give the model a spec so clear that a junior developer could implement it
without asking a single question.

---

## The Core Template

```
SYSTEM:
You are a code-completion engine. Follow the spec exactly.
Output only valid {LANGUAGE} code.
Do not explain. Do not add markdown fences. Do not add extra functions.

CONTEXT:
{PASTE THE SPEC / INTERFACE / TYPES / SCHEMA HERE}

TASK:
{ONE CONCRETE INSTRUCTION}
```

---

## What makes a good CONTEXT block

Include whatever makes the task unambiguous:

| Situation | Include in CONTEXT |
|---|---|
| Implementing a function | Its signature, docstring, and the types it uses |
| Writing tests | The function under test, its signature, and 1–2 example inputs/outputs |
| Generating a schema | The existing related schemas + field descriptions |
| CRUD layer | The model definition + the interface it must satisfy |
| Type stubs | The raw JS/Python + the target typed interface |

**Do not** include unrelated code — it confuses small models.

---

## What makes a good TASK instruction

- One deliverable per call
- Use the exact name from the spec
- State the output format explicitly

**Good:**
> Implement the function `validateEmail(input: string): ValidationResult` from the spec above. Return only the function body.

**Bad:**
> Write the validation utilities.

---

## Worked Examples

### Example 1 — Implement a typed function (TypeScript)

```
SYSTEM:
You are a code-completion engine. Output only valid TypeScript. No markdown. No explanation.

CONTEXT:
type User = { id: string; email: string; role: 'admin' | 'viewer' };
type ValidationResult = { valid: boolean; error?: string };

// validateEmail checks that email is non-empty and contains '@'
// Returns { valid: true } on success, { valid: false, error: "..." } on failure

TASK:
Implement validateEmail(input: string): ValidationResult
```

---

### Example 2 — Write a pytest test

```
SYSTEM:
You are a test-writing engine. Output only valid Python. No markdown. No imports (they're handled).

CONTEXT:
def parse_config(raw: str) -> dict:
    """
    Parses a KEY=VALUE config string, one pair per line.
    Ignores lines starting with '#'. Raises ValueError on malformed lines.
    Example: parse_config("HOST=localhost\nPORT=5432") -> {"HOST": "localhost", "PORT": "5432"}
    """

TASK:
Write three pytest test functions for parse_config:
1. A happy-path test with two valid pairs
2. A test that verifies '#' lines are ignored
3. A test that verifies ValueError is raised for a malformed line
```

---

### Example 3 — Generate a Zod schema from a design doc

```
SYSTEM:
You are a schema-generation engine. Output only valid TypeScript using Zod. No markdown.

CONTEXT:
Design doc — UserProfile:
- id: UUID string, required
- displayName: string, 2–50 chars, required
- bio: string, max 300 chars, optional
- avatarUrl: URL string, optional
- createdAt: ISO date string, required

TASK:
Generate the Zod schema `UserProfileSchema` for the UserProfile type above.
```

---

## Anti-patterns to avoid

| Anti-pattern | Why it fails | Fix |
|---|---|---|
| "Write all the CRUD routes" | Too broad — model loses track | One route per call |
| No type context | Model invents types | Always include interfaces/types |
| "Fix this" with no spec | Ambiguous — not a well-defined task | Use a remote model instead |
| Asking for explanation | Wastes tokens, model drifts | System prompt: "No explanation" |
| Long context with unrelated code | Model anchors on wrong code | Trim context to the relevant piece |
