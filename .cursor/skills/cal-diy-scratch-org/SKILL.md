---
name: cal-diy-scratch-org
description: >-
  Creates a 30-day Salesforce scratch org for cal.diy, deploys force-app,
  assigns Scheduling permission sets, and opens the org. Use when setting up
  cal.diy development, creating a new scratch org, refreshing an expired org,
  or when the user mentions cal-diy-dev, scratch org, or cal.diy deployment.
---

# cal.diy Scratch Org Setup

Uses `config/project-scratch-def.json` (project targets 30-day orgs; `durationDays` in the file is not accepted by current SF CLI — pass `-y 30` and strip `durationDays` from the def if create fails with `unrecognizedScratchOrgOption`).

## Prerequisites

- Salesforce CLI (`sf`) authenticated
- Dev Hub available (default alias: `devOrg`)
- Run from project root: `c:\Users\incap\Documents\GitHub\cal.diy`

## Workflow

Copy and track progress:

```
- [ ] Resolve org alias
- [ ] Create scratch org
- [ ] Deploy force-app
- [ ] Assign permission sets
- [ ] Set default org and open
- [ ] Report org details
```

### Step 1: Resolve alias and Dev Hub

Preferred alias: `cal-diy-dev`. Fallback: `cal-diy-scratch`.

```bash
sf org list
```

- If preferred alias exists and is active, use it or delete with `sf org delete scratch -o <alias> -p` then recreate.
- Dev Hub: use `-v devOrg`. If missing, pick the connected Dev Hub from `sf org list` (`isDevHub: true`).

### Step 2: Create scratch org

```bash
sf org create scratch -f config/project-scratch-def.json -a cal-diy-dev -v devOrg -y 30
```

Replace `devOrg` with detected Dev Hub alias if needed.

**`durationDays` in def file:** Current SF CLI rejects `durationDays` inside `project-scratch-def.json`. Pass `-y 30` on the command. If create fails with `unrecognizedScratchOrgOption` / `durationDays`, strip that key from a temp copy of the def file before running create.

### Step 3: Deploy metadata

```bash
sf project deploy start --source-dir force-app --target-org cal-diy-dev --test-level RunLocalTests
```

Add `--ignore-conflicts` if source tracking conflicts appear.

**Coverage gate fallback:** If deploy fails on test coverage or test failures:

```bash
sf project deploy start --source-dir force-app --target-org cal-diy-dev --test-level NoTestRun --ignore-conflicts
sf apex run test --target-org cal-diy-dev --test-level RunLocalTests --result-format human --wait 30
```

### Step 4: Assign permission sets

Assign to the scratch org default admin user:

```bash
sf org assign permset --name Scheduling_Host --target-org cal-diy-dev
sf org assign permset --name Scheduling_Admin --target-org cal-diy-dev
```

### Step 5: Set default org and open

```bash
sf config set target-org cal-diy-dev
sf org open --target-org cal-diy-dev
```

### Step 6: Report

Return:

| Field | Source |
|-------|--------|
| Alias | `-a` value |
| Username | `sf org display --target-org <alias> --json` |
| Instance URL | same |
| Expiration | `expirationDate` from org list or display |
| Deploy result | success/failure, component counts |
| Test count | from deploy or `sf apex run test` output |

## Post-setup (manual in org)

See **`docs/NEXT_SESSION.md`** for the full checklist. Minimum:

1. **Integrations** — Admin user must authenticate Google and Microsoft on the Integrations page.
2. **Email deliverability** — Setup → Deliverability → set to **All Email**.
3. **Google OAuth redirect URIs** — Add the scratch org callback URLs to the Google Cloud OAuth client (from Integrations admin UI or Connected App callback URL).
4. **Zoom** — Set `Zoom_User_Id__c` (and Account ID / credentials) in Scheduling Settings for S2S meeting creation.

## Optional script

Run end-to-end on Windows:

```powershell
.cursor/skills/cal-diy-scratch-org/scripts/create-scratch-org.ps1
```

Optional `-Alias` and `-DevHub` parameters override defaults.
