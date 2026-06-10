# cal.diy HRIS Package Plan

**Status:** Planning document (no implementation yet)  
**Last updated:** 2026-06-05  
**Repo state:** Monolithic `force-app/main/default` with HRIS code co-located; org coverage ~73% vs 75% CI gate

---

## Executive summary

cal.diy should split HRIS workforce sync into an **optional extension package** (`cal.diy-hris`) that depends on **core scheduling** (`cal.diy-core`). Core already has the right conceptual seams—`Hr_Integration_Provider__mdt`, abstract providers, `Out_of_Office__c` / `Schedule__c` sync targets—but the implementation is still monolithic: `HrSyncService` hard-codes a provider `switch`, Workday-specific logic lives in `IntegrationsAdminController`, and `SchedulingJobService` always schedules HR cron jobs.

This plan defines package boundaries, extension points core must expose, a provider roadmap for nine HRIS vendors, migration steps, phased delivery, and product decisions.

---

## 1. Package architecture (2GP / unlocked)

### 1.1 Package split

| Package | Alias | Role | Install model |
|---------|-------|------|---------------|
| **cal.diy-core** | `core` | Scheduling, bookings, calendar sync, payments, integrations admin shell, shared workforce data model | Required base |
| **cal.diy-hris** | `hris` | HRIS provider implementations, credentials templates, HR cron jobs, HR-specific CMDT records, admin health checks for HR | Optional add-on |

**Dependency:** `cal.diy-hris` declares a package dependency on `cal.diy-core` (minimum version pinned per release).

**Recommended path:**

1. **Phase 0–1:** Unlocked packages in a multi-root SFDX repo (fast iteration, same org installs both).
2. **Phase 2+:** Promote to **2GP** (managed or unlocked) for AppExchange / subscriber upgrades.

### 1.2 Namespace strategy

| Approach | When to use |
|----------|-------------|
| **Unlocked, no namespace (dev)** | Current repo style; fastest split validation |
| **Single ISV namespace `caldiy`** | 2GP managed: core + hris as separate packages under one namespace (hris is dependent package) |
| **Dual namespace** | Only if legal/ISV requirements force it; avoid unless necessary |

**Convention:**

- Core global Apex/LWC: `caldiy` prefix or unprefixed in unlocked dev.
- HRIS implementations: same namespace, distinct package directory.
- Custom objects in core keep `__c` suffix; CMDT types owned by core use `__mdt`.

### 1.3 What stays in core vs moves to HRIS

#### Stays in **cal.diy-core**

| Area | Artifacts (current) | Rationale |
|------|---------------------|-----------|
| Scheduling domain | `Schedule__c`, `Availability__c`, `Out_of_Office__c`, booking/slot services | HRIS writes into these; core owns booking behavior |
| Workforce schema (generic) | `Source__c`, `External_Id__c` on OOO / Schedule / Availability | Sync targets must exist without HRIS installed |
| Extension contracts | `HrAbsenceSyncProvider`, `HrScheduleSyncProvider`, `HrSyncService` (orchestrator only), `HrSyncService.ProviderSyncResult` | Stable API surface for extensions |
| Provider registry CMDT **type** | `Hr_Integration_Provider__mdt` object + fields | Contract between core admin UI and extensions |
| Integrations admin (generic) | `integrationsAdmin` LWC, `IntegrationsAdminController` (HR-agnostic portions) | One admin surface; HR cards driven by metadata |
| Job framework hook | `SchedulingJobService` with registrable extensions | Core schedules calendar jobs; HRIS registers HR job |
| User resolution utility | `HrUserResolver` | Generic worker-id / email mapping; no vendor logic |
| Constants (minimal) | `HrIntegrationProvider.MANUAL` only, or drop class in favor of CMDT | Core must not reference Workday/UKG/etc. |

#### Moves to **cal.diy-hris**

| Area | Artifacts (current) | Rationale |
|------|---------------------|-----------|
| Provider implementations | `Workday*`, `Ukg*`, `Adp*`, `SuccessFactors*` sync providers + tests | Vendor-specific |
| HTTP/report client | `HrReportClient` (or rename `HrisReportClient`) | Used only by HRIS providers today |
| HR batch / schedulable | `HrWorkforceSyncBatch`, `HrWorkforceSyncSchedulable`, tests | Optional feature |
| Provider CMDT **records** | `Hr_Integration_Provider.Workday`, `.UKG`, `.ADP`, `.SuccessFactors` (+ future) | Shipped with implementations |
| Credentials templates | `Workday_API` named credential, `Workday_Credential` external credential | Per-vendor setup |
| User extension fields | `User.Workday_Worker_Id__c` (+ future `UKG_Employee_Id__c`, etc.) | Provider-specific mapping |
| Legacy Workday settings | `Scheduling_Settings__mdt` fields: `Workday_*` | Deprecate in favor of provider CMDT |
| HR-specific permission set fields | FLS for Workday principal, HR sync classes | `Scheduling_HRIS_Admin` or extend `Scheduling_Admin` in hris package |
| Workday facade | `WorkdayAbsenceService` | Thin wrapper; can fold into provider |

#### Shared / refactor boundary

| Concern | Owner | Notes |
|---------|-------|-------|
| `HrSyncService.createAbsenceProvider` / `createScheduleProvider` switch | **Core** (refactored to registry) | Replace `switch` with `Type.forName` from CMDT |
| `IntegrationsAdminController.buildHrProviderStatus` Workday branch | **Core** (generic) + **HRIS** (optional status enricher) | See §3 |
| `SchedulingJobService.scheduleHrWorkforceSync` | **Core** hook, **HRIS** registration | HR job only scheduled when hris package present |
| `Source__c` picklist values | **Core** GVS + **HRIS** adds values | See §3.3 |

### 1.4 Extension points core must expose

#### A. Provider factory (required)

Add fields to `Hr_Integration_Provider__mdt`:

| Field | Type | Purpose |
|-------|------|---------|
| `Absence_Provider_Class__c` | Text(255) | Fully-qualified Apex class extending `HrAbsenceSyncProvider` |
| `Schedule_Provider_Class__c` | Text(255) | Fully-qualified Apex class extending `HrScheduleSyncProvider` |
| `Status_Enricher_Class__c` | Text(255), optional | Implements `HrIntegrationStatusEnricher` for admin UI |
| `Sort_Order__c` | Number | Card ordering in Integrations admin |

`HrSyncService` becomes:

```apex
// Pseudocode — core only
HrAbsenceSyncProvider p = (HrAbsenceSyncProvider) Type.forName(cmdt.Absence_Provider_Class__c)
    ?.newInstance(new List<Object>{ cmdt });
```

No `when 'Workday'` branches in core.

#### B. Job registration interface (required)

```apex
// Core
public interface HrWorkforceJobRegistrar {
    void registerJobs(SchedulingJobService.JobRegistry registry);
}
```

- Core `SchedulingJobService.scheduleAllJobs()` calls all registrars discovered via `Type.forName` from Custom Metadata `Hris_Job_Registrar__mdt` (core type, hris record).
- HRIS package ships registrar that schedules `CalDIY_HrWorkforceSync`.
- When HRIS not installed, `scheduleAllJobs()` skips HR cron; Integrations admin shows HR section as "HRIS package not installed" (optional CMDT flag).

#### C. Integrations admin provider cards (required)

Core returns `IntegrationStatus` rows for every `Hr_Integration_Provider__mdt` record using **generic rules**:

- `Is_Implemented__c == false` → `coming_soon`
- `Is_Enabled__c == false` → `not_configured`
- `Is_Enabled__c && Is_Implemented__c` → delegate to optional `HrIntegrationStatusEnricher` via `Status_Enricher_Class__c`, else `partial` with `Setup_Guidance__c`

Remove Workday-specific branches (`hasWorkdayAbsencePath`, `EXTERNAL_CREDENTIAL_NAMES['Workday']`) from core; Workday enricher lives in hris package.

#### D. Global Apex accessibility

- Base classes `HrAbsenceSyncProvider`, `HrScheduleSyncProvider`: `global virtual` if 2GP managed cross-package extension is required; `public virtual` sufficient for unlocked same-org.
- Result DTO `HrSyncService.ProviderSyncResult`: `public` in core.

#### E. Optional: Platform Event (future)

`Hris_Sync_Completed__e` (core event type, hris publisher) for observability / webhook fan-out. Not required for v1.

### 1.5 Refactoring needed before / during split

| # | Task | Effort |
|---|------|--------|
| 1 | Replace `HrSyncService` provider `switch` with CMDT-driven `Type.forName` | S |
| 2 | Extract Workday-specific status/health checks from `IntegrationsAdminController` to `WorkdayIntegrationStatusEnricher` | S |
| 3 | Decouple `SchedulingJobService.scheduleHrWorkforceSync` from unconditional call in `scheduleAllJobs` | S |
| 4 | Migrate `Scheduling_Settings__mdt.Workday_*` paths to `Hr_Integration_Provider__mdt` (keep read fallback one release) | S |
| 5 | Introduce Global Value Set for `Source__c` or change to Text | M |
| 6 | Move 20+ Apex classes + credentials + CMDT records to `packages/hris` | M |
| 7 | Update tests: core tests mock registry; hris tests cover providers | M |
| 8 | Remove `HrIntegrationProvider.WORKDAY/UKG/...` constants from core (or keep only `MANUAL`) | S |

### 1.6 Target directory layout

```
cal.diy/
├── sfdx-project.json                 # multi-packageDirectories
├── packages/
│   ├── core/
│   │   └── main/default/             # today's force-app minus HRIS
│   └── hris/
│       └── main/default/             # HRIS-only metadata
├── config/
│   ├── project-scratch-def.json      # core scratch
│   └── project-scratch-def-hris.json # core + hris second-gen scratch
└── docs/
    └── HRIS_PACKAGE_PLAN.md
```

**sfdx-project.json (illustrative):**

```json
{
  "packageDirectories": [
    { "path": "packages/core", "default": true, "package": "cal.diy-core", "versionNumber": "1.0.0.NEXT" },
    { "path": "packages/hris", "package": "cal.diy-hris", "versionNumber": "1.0.0.NEXT", "dependencies": [
      { "package": "cal.diy-core", "versionNumber": "1.0.0.LATEST" }
    ]}
  ],
  "name": "cal-scheduling",
  "namespace": "",
  "sourceApiVersion": "62.0"
}
```

---

## 2. Provider roadmap — all HRIS competitors

### 2.1 Priority order (recommended)

| Priority | Provider | Segment | Rationale |
|----------|----------|---------|-----------|
| P1 | **Workday** | Enterprise HCM | Already implemented (RaaS); anchor enterprise deal |
| P2 | **UKG** | Workforce mgmt / hourly | Large installed base; strong shift scheduling |
| P2 | **ADP Workforce Now** | Mid-market HR + payroll | Broad US mid-market overlap with cal.diy buyers |
| P3 | **SAP SuccessFactors** | Enterprise SAP shops | OData time APIs; common in global enterprises |
| P3 | **Oracle HCM Cloud** | Enterprise Oracle stack | REST/SOAP HCM; long sales cycles |
| P3 | **Ceridian Dayforce** | Enterprise payroll+HCM | Unified tenant API; Canadian/US enterprise |
| P4 | **BambooHR** | SMB | Fast setup; time-off only (limited schedule) |
| P4 | **Rippling** | SMB / mid-market IT+HR | Modern API; growing cal.diy SMB segment |
| P5 | **Paylocity** | Mid-market payroll | Relevant US mid-market; narrower API surface |

### 2.2 Provider detail matrix

#### Workday (v1 — in progress)

| Dimension | Plan |
|-----------|------|
| **Absence sync** | RaaS JSON custom report → `Out_of_Office__c` (implemented) |
| **Schedule sync** | RaaS worker schedule report → `Schedule__c` + `Availability__c` (implemented) |
| **API approach** | Report-as-a-Service (RaaS) via Named Credential; avoids WWS SOAP complexity for v1 |
| **Auth model** | Integration System User (ISU); `Workday_Credential` external credential + `Workday_Principal` on Scheduling Admin perm set |
| **Worker mapping** | `Workday_Worker_Id__c` on User or email fallback (`HrUserResolver`) |
| **Effort** | **M** to production-ready (error handling, idempotency hardening, docs, depre. settings fields) |
| **Gaps** | `Workday_Sync_Days_Ahead__c` unused; no incremental sync watermark; health checks hardcoded in admin controller |

#### UKG (Kronos / Dimensions / Pro)

| Dimension | Plan |
|-----------|------|
| **Absence sync** | UKG Pro **Time Off** REST or Dimensions **Time Off** API → OOO |
| **Schedule sync** | Dimensions **Scheduling** / **Shifts** API → Schedule + Availability (hourly patterns) |
| **API approach** | REST JSON; separate paths for UKG Pro vs Dimensions (two CMDT records or `Provider_Variant__c`) |
| **Auth model** | OAuth 2.0 client credentials (Dimensions) or API key + customer-specific base URL |
| **Worker mapping** | `UKG_Employee_Id__c` or `UKG_Person_Number__c` on User |
| **Effort** | **L** (multi-product API surface, tenant URL per customer) |
| **Priority** | P2 — Phase 2 |

#### ADP Workforce Now

| Dimension | Plan |
|-----------|------|
| **Absence sync** | ADP Time Off / Leave requests API |
| **Schedule sync** | Worker schedules / work schedules (where licensed) |
| **API approach** | ADP Marketplace REST APIs; event notification optional for near-real-time |
| **Auth model** | OAuth 2.0 (certificate-based for production ADP apps) |
| **Worker mapping** | `ADP_Associate_OID__c` or email |
| **Effort** | **M–L** (ADP partner onboarding, cert management) |
| **Priority** | P2 — Phase 2 |

#### SAP SuccessFactors

| Dimension | Plan |
|-----------|------|
| **Absence sync** | OData v2 `EmployeeTime`, `TimeAccount` |
| **Schedule sync** | `WorkSchedule` / `HolidayCalendar` entities |
| **API approach** | OData v2/v4 REST |
| **Auth model** | OAuth 2.0 SAML bearer or API user; company-specific API endpoint |
| **Worker mapping** | `SF_User_Id__c` or `personIdExternal` |
| **Effort** | **L** (OData pagination, SF-specific filters, multi-entity joins) |
| **Priority** | P3 — Phase 3 |

#### Oracle HCM Cloud

| Dimension | Plan |
|-----------|------|
| **Absence sync** | REST **Absences** / HCM Extract or BIP report |
| **Schedule sync** | Work schedules via HCM REST or extract |
| **API approach** | REST preferred; BIP report fallback (similar to Workday RaaS pattern) |
| **Auth model** | OAuth 2.0 / IDCS; basic for extract endpoints |
| **Worker mapping** | `Oracle_Person_Number__c` |
| **Effort** | **L** |
| **Priority** | P3 — Phase 3 |

#### Ceridian Dayforce

| Dimension | Plan |
|-----------|------|
| **Absence sync** | Dayforce REST **Employee Time Away** |
| **Schedule sync** | **Schedule** / shift endpoints |
| **API approach** | REST JSON, single-tenant `host` per customer |
| **Auth model** | OAuth 2.0 / service account |
| **Worker mapping** | `Dayforce_XRef_Code__c` |
| **Effort** | **M–L** |
| **Priority** | P3 — Phase 3 |

#### BambooHR

| Dimension | Plan |
|-----------|------|
| **Absence sync** | `time_off/requests` + `time_off/policies` |
| **Schedule sync** | **Limited** — BambooHR is not a WFM; optional "expected hours" from employee directory only |
| **API approach** | REST, API key in subdomain URL |
| **Auth model** | API key (per subdomain) |
| **Worker mapping** | Email / `BambooHR_Employee_Id__c` |
| **Effort** | **S–M** |
| **Priority** | P4 — Phase 4 |

#### Rippling

| Dimension | Plan |
|-----------|------|
| **Absence sync** | Time off / leave API |
| **Schedule sync** | Work schedule if exposed; may be absence-only v1 |
| **API approach** | REST Platform API |
| **Auth model** | OAuth 2.0 API token |
| **Worker mapping** | Rippling worker ID or email |
| **Effort** | **M** |
| **Priority** | P4 — Phase 4 |

#### Paylocity (if relevant)

| Dimension | Plan |
|-----------|------|
| **Absence sync** | Paylocity Web Link API time-off endpoints |
| **Schedule sync** | Not primary; skip v1 unless customer demand |
| **API approach** | REST (partner program) |
| **Auth model** | OAuth 2.0 |
| **Worker mapping** | `Paylocity_Employee_Id__c` |
| **Effort** | **S–M** (absence-only) |
| **Priority** | P5 — backlog / Phase 4+ |
| **Relevance** | US mid-market; include if target ICP includes Paylocity-heavy verticals |

### 2.3 Cross-provider implementation patterns

Reuse from current Workday implementation:

1. **Report/extract pattern** (`HrReportClient`) — Workday RaaS, Oracle BIP, ADP custom reports.
2. **REST pagination pattern** — UKG, ADP, Rippling, BambooHR.
3. **OData pattern** — SuccessFactors (generic OData client in hris package).
4. **Common sync pipeline:** fetch → parse rows → resolve user → upsert by `External_Id__c` → cancel stale by source.
5. **Idempotency key:** `{Provider_Key__c}:{vendorId}` on `External_Id__c` (already used).

Each new provider ships:

- `*AbsenceSyncProvider`, `*ScheduleSyncProvider` (or stub returning guided error until implemented)
- `Hr_Integration_Provider.*` CMDT record with class names
- Named + external credential templates
- User field for worker ID
- Tests with `HrReportClient.skipCallouts` / HTTP mock
- Setup guide section in admin docs

---

## 3. Core package changes required

### 3.1 Minimal hooks (core must not know Workday)

| Component | Change |
|-----------|--------|
| `HrSyncService` | CMDT registry only; zero vendor imports |
| `IntegrationsAdminController` | Generic HR provider loop; optional enricher interface |
| `SchedulingJobService` | Pluggable job registrars; no direct `HrWorkforceSyncSchedulable` reference |
| `SchedulingController.scheduleBackgroundJobs` | Unchanged signature; behavior via registrars |
| Health checks | Generic "HR sync job failed" if batch class exists in org; vendor checks in enricher |

### 3.2 `Hr_Integration_Provider__mdt` — core or extension?

**Recommendation: CMDT type in core; records in hris package.**

| Reason | Detail |
|--------|--------|
| Admin UI | Core Integrations page queries one CMDT type |
| Extensibility | Future `cal.diy-hris-payroll` could add more records to same type |
| 2GP | Dependent package can ship CMDT records for types defined in dependency |

**Core owns fields** (existing + new):

- `Provider_Key__c`, `Is_Enabled__c`, `Is_Implemented__c`
- `Named_Credential__c`, `Absence_Report_Path__c`, `Schedule_Report_Path__c`
- `Worker_Id_User_Field__c`, `Setup_Guidance__c`
- **New:** `Absence_Provider_Class__c`, `Schedule_Provider_Class__c`, `Status_Enricher_Class__c`, `Sort_Order__c`

Generic path fields stay on CMDT (not `Scheduling_Settings__mdt`) to avoid core knowing Workday.

### 3.3 Integrations admin: dynamic cards vs hardcoded LWC

**Current state:** LWC is already dynamic (`integrations` array from Apex). Hardcoding is in `IntegrationsAdminController.buildHrProviderStatus` (Workday-specific) and `EXTERNAL_CREDENTIAL_NAMES` map.

**Target:**

- LWC: no change required; continues to render whatever Apex returns.
- Apex: one generic `buildHrProviderStatus(provider)` + enricher hook.
- HRIS package: one enricher class per vendor (optional).
- Overview fields `hrWorkforceSyncJobScheduled`, `hrWorkforceSyncLastSync` — populate only if `HrWorkforceSyncBatch` class exists (`Type.forName` check).

### 3.4 `SchedulingJobService` extension for HR cron

**Current:**

```apex
public static void scheduleAllJobs() {
    scheduleCalendarSync();
    scheduleWorkflowReminders();
    scheduleHrWorkforceSync();  // unconditional — problematic for core-only installs
}
```

**Target:**

```apex
public static void scheduleAllJobs() {
    scheduleCalendarSync();
    scheduleWorkflowReminders();
    for (HrisJobRegistrar registrar : HrisJobRegistry.loadRegistrars()) {
        registrar.register(this);
    }
}
```

HRIS registrar schedules `CalDIY_HrWorkforceSync` at `0 30 * * * ?` (hourly at :30). Core tests verify HR job **not** scheduled when hris package absent.

### 3.5 Shared objects — who owns schema?

| Object / field | Owner | Notes |
|----------------|-------|-------|
| `Out_of_Office__c` | **Core** | Object + `User__c`, `Start_Date__c`, `End_Date__c`, `Status__c`, `Reason__c`, `Absence_Type__c`, `External_Id__c` |
| `Out_of_Office__c.Source__c` | **Core** field; **HRIS** adds picklist values | Use **Global Value Set** `Scheduling_Record_Source` defined in core with `Manual`; hris package adds Workday, UKG, etc. |
| `Schedule__c.Source__c` | Same GVS | |
| `Availability__c.Source__c` | Same GVS | |
| `Schedule__c.External_Id__c` | **Core** | HRIS writes prefixed external IDs |
| `User.*_Worker_Id__c` fields | **HRIS** | Provider-specific; referenced by CMDT `Worker_Id_User_Field__c` |
| `Scheduling_Settings__mdt.Workday_*` | **Deprecate** | Migrate to provider CMDT; core removes in major version |

**Booking impact:** `TeamSchedulingService` already queries `Out_of_Office__c` by date range (ignores `Source__c`) — no core change needed when HRIS writes OOO records.

---

## 4. Migration plan

### 4.1 Extract HRIS code from monolithic force-app

**Step-by-step:**

1. Create `packages/core` and `packages/hris` directories.
2. Copy entire `force-app/main/default` → `packages/core/main/default`.
3. Move HRIS artifacts from core → hris (list in §1.3).
4. Apply core refactors (registry, job hook, admin generic).
5. Update `sfdx-project.json` to multi-package.
6. Delete original `force-app/` after validation (or keep as deprecated alias one sprint).
7. Run full test suite in scratch org with both packages deployed.

**Apex classes to move (18+):**

- `WorkdayAbsenceService`, `WorkdayAbsenceSyncProvider`, `WorkdayScheduleSyncProvider`
- `WorkdayAbsenceServiceTest`, `WorkdayAbsenceSyncProviderTest`, `WorkdayScheduleSyncProviderTest`
- `UkgAbsenceSyncProvider`, `UkgScheduleSyncProvider`
- `AdpAbsenceSyncProvider`, `AdpScheduleSyncProvider`
- `SuccessFactorsAbsenceSyncProvider`, `SuccessFactorsScheduleSyncProvider`
- `HrReportClient`, `HrWorkforceSyncBatch`, `HrWorkforceSyncSchedulable`, `HrWorkforceSyncBatchTest`
- Future: `*IntegrationStatusEnricher`, `HrisJobRegistrarImpl`

**Metadata to move:**

- `customMetadata/Hr_Integration_Provider.*`
- `namedCredentials/Workday_API.*`
- `externalCredentials/Workday_Credential.*`
- `objects/User/fields/Workday_Worker_Id__c.*`

**Metadata to refactor in core:**

- Remove Workday from `IntegrationsAdminController.EXTERNAL_CREDENTIAL_NAMES`
- Remove `Scheduling_Settings__mdt` Workday fields (post-migration)
- Trim `Source__c` inline values → Global Value Set

### 4.2 Scratch org definitions

**`config/project-scratch-def.json`** (core only):

- Unchanged; used for core CI and subscribers without HRIS.

**`config/project-scratch-def-hris.json`** (core + hris):

- Same features as core.
- Used for HRIS development and full integration tests.

**Deploy commands:**

```bash
sf org create scratch -f config/project-scratch-def.json -a cal-core -d 7
sf project deploy start --source-dir packages/core --target-org cal-core

sf org create scratch -f config/project-scratch-def-hris.json -a cal-hris -d 7
sf project deploy start --source-dir packages/core --target-org cal-hris
sf project deploy start --source-dir packages/hris --target-org cal-hris
```

### 4.3 CI / deploy order

| Job | Steps |
|-----|-------|
| **core-ci** | Deploy `packages/core` → `RunLocalTests` → enforce **75% org coverage** |
| **hris-ci** | Depends on core-ci artifact; deploy core then hris → `RunLocalTests` (or specified HRIS test suite) |
| **full-ci** (main branch) | Both packages; E2E against hris scratch |

Update `.github/workflows/ci.yml`:

```yaml
- name: Deploy Core
  run: sf project deploy start --source-dir packages/core --target-org ci-org --wait 30
- name: Deploy HRIS
  run: sf project deploy start --source-dir packages/hris --target-org ci-org --wait 30
```

**Version pinning:** When using 2GP, CI installs `cal.diy-core@x.y.z` from Dev Hub, then pushes hris beta.

### 4.4 Subscriber install flows

| Profile | Install |
|---------|---------|
| Scheduling only | `cal.diy-core` |
| Enterprise HRIS | `cal.diy-core` + `cal.diy-hris` |
| Upgrade | Core first, then hris; never hris without matching core min version |

### 4.5 Coverage impact (73% → 75%)

- Splitting HRIS tests into hris package isolates heavy mock tests.
- Core shed ~8–12 Apex classes (providers + Workday tests) → core coverage should rise.
- HRIS package sets its own 75% gate on **local** tests.
- Until split lands, prioritize tests for `IntegrationsAdminController` HR paths and `WorkdayScheduleSyncProvider` edge cases to clear org gate.

---

## 5. Implementation phases

### Phase 0: Package split + extension architecture (2–3 sprints)

**Goal:** Physical split with no behavioral regression.

| Milestone | Deliverables |
|-----------|--------------|
| M0.1 | Multi-package repo layout; CI deploys core then hris |
| M0.2 | `HrSyncService` registry refactor; remove provider switch |
| M0.3 | `SchedulingJobService` registrar pattern |
| M0.4 | Generic HR integrations admin; Workday enricher in hris |
| M0.5 | Global Value Set for `Source__c`; deprecate `Scheduling_Settings.Workday_*` |
| M0.6 | Documentation: install guide for optional hris package |

**Exit criteria:** Scratch org with core-only has no HR cron, no HR provider classes; scratch with both packages matches current Workday behavior.

### Phase 1: Workday production-ready in HRIS package (1–2 sprints)

**Goal:** First commercial HRIS integration.

| Milestone | Deliverables |
|-----------|--------------|
| M1.1 | Workday absence + schedule sync hardening (error messages, governor limits) |
| M1.2 | Implement `Workday_Sync_Days_Ahead__c` or remove field |
| M1.3 | Stale record cancellation tests; large workforce batching strategy |
| M1.4 | Admin setup guide + ISU credential documentation |
| M1.5 | Optional: manual "Sync now" action on Integrations admin |
| M1.6 | 75%+ coverage on all Workday/hris classes |

**Exit criteria:** Pilot customer syncs absences + schedules hourly with monitoring in Integrations admin.

### Phase 2: UKG + ADP (3–4 sprints)

| Milestone | Deliverables |
|-----------|--------------|
| M2.1 | UKG Dimensions absence sync (REST) |
| M2.2 | UKG Dimensions schedule/shift sync |
| M2.3 | ADP Workforce Now absence sync |
| M2.4 | ADP schedule sync (if API available on license) |
| M2.5 | CMDT records + credentials templates + perm sets |

**Exit criteria:** Two non-Workday enterprise pilots; stubs replaced with `Is_Implemented__c = true`.

### Phase 3: SuccessFactors + Oracle + Dayforce (4–6 sprints)

| Milestone | Deliverables |
|-----------|--------------|
| M3.1 | OData client utility in hris package |
| M3.2 | SuccessFactors absence + work schedule |
| M3.3 | Oracle HCM absence (REST or BIP) |
| M3.4 | Dayforce absence + schedule |
| M3.5 | Enterprise security review (named credentials, PII logging) |

### Phase 4: SMB providers (2–3 sprints)

| Milestone | Deliverables |
|-----------|--------------|
| M4.1 | BambooHR time-off sync |
| M4.2 | Rippling time-off (+ schedule if API supports) |
| M4.3 | Paylocity absence (if prioritized) |
| M4.4 | Simplified SMB setup wizard steps |

### Testing strategy

| Layer | Scope |
|-------|-------|
| **Unit** | Each `*SyncProvider`, `HrReportClient`, `HrUserResolver`, enrichers, registrar |
| **Integration** | `HrSyncService.syncAll` with multiple enabled providers |
| **Batch** | `HrWorkforceSyncBatch` with mock callouts |
| **Admin** | `IntegrationsAdminController` generic + enricher |
| **E2E** | Integrations tab shows HR cards; setup wizard schedules jobs when hris installed |
| **Regression** | Booking slot exclusion still honors synced OOO (`TeamSchedulingService`) |

### Admin docs & Integrations UI

| Doc | Audience |
|-----|----------|
| `docs/HRIS_INSTALL.md` | Which package to install |
| `docs/HRIS_WORKDAY_SETUP.md` | ISU, RaaS, field mapping |
| Per-provider pages | Added as providers ship |
| Integrations admin | In-app `Setup_Guidance__c` from CMDT (already pattern) |

---

## 6. Open questions / decisions for product owner

| # | Question | Options | Recommendation |
|---|----------|---------|----------------|
| 1 | **2GP managed vs unlocked?** | Unlocked for internal; managed for AppExchange | Unlocked now; managed before GA AppExchange |
| 2 | **Namespace** | Single `caldiy` vs none | Single namespace before AppExchange |
| 3 | **Pricing / packaging** | HRIS included vs paid add-on | Paid add-on or enterprise tier (TBD) |
| 4 | **Core-only subscribers** | Hide HR section vs show "Install HRIS package" | Show upsell card with link to docs |
| 5 | **`Source__c` data type** | Restricted picklist vs Text vs GVS | Global Value Set (core Manual + hris values) |
| 6 | **Multi-HRIS per org** | One enabled provider vs many | **Many allowed** (current CMDT model); document conflict rules for schedule defaults |
| 7 | **Schedule overwrite policy** | HRIS overwrites default schedule vs creates secondary | Current: sets `Is_Default__c = true` — confirm with product |
| 8 | **Sync frequency** | Hourly batch vs near-real-time | Hourly for v1; webhooks in Phase 3+ |
| 9 | **Worker identity** | Per-vendor User fields vs generic `Hris_Worker_Id__c` | Per-vendor fields (flexible, CMDT-driven) |
| 10 | **PII / logging** | What appears in debug logs and health checks | No employee names in errors; admin-only detail |
| 11 | **Paylocity priority** | Include in Phase 4 vs backlog | Backlog unless sales names ≥3 Paylocity prospects |
| 12 | **UKG product scope** | Dimensions only vs Pro + Dimensions | Dimensions first (shift-heavy); Pro time-off second |
| 13 | **Coverage gate** | Org-wide 75% vs per-package | Per-package gates after split; org-wide on full install |
| 14 | **Experience Cloud** | HRIS admin only in internal org | Internal only for v1 |
| 15 | **Deprecation** | `Scheduling_Settings__mdt.Workday_*` | One-release fallback then remove |

---

## Appendix A — Current repo inventory (HRIS-related)

### Implemented (Workday)

- `WorkdayAbsenceSyncProvider`, `WorkdayScheduleSyncProvider`, `WorkdayAbsenceService`
- RaaS JSON via `HrReportClient` → OOO + Schedule/Availability upsert
- Credentials: `Workday_API`, `Workday_Credential`
- CMDT: `Hr_Integration_Provider.Workday` (`Is_Implemented__c = true`)

### Stubs (throw "not yet implemented")

- `UkgAbsenceSyncProvider`, `UkgScheduleSyncProvider`
- `AdpAbsenceSyncProvider`, `AdpScheduleSyncProvider`
- `SuccessFactorsAbsenceSyncProvider`, `SuccessFactorsScheduleSyncProvider`

### Orchestration (to refactor in core)

- `HrSyncService` — hardcoded provider factory
- `HrWorkforceSyncBatch` / `HrWorkforceSyncSchedulable` — hourly sync
- `SchedulingJobService.scheduleHrWorkforceSync` — unconditional
- `IntegrationsAdminController` — Workday-specific status + health checks

### Schema

- `Out_of_Office__c`, `Schedule__c`, `Availability__c` — `Source__c` picklist (Manual, Workday, UKG, ADP, SuccessFactors)
- `External_Id__c` on OOO, Schedule, Availability
- `User.Workday_Worker_Id__c`

### Not yet in repo

- Oracle, Dayforce, BambooHR, Rippling, Paylocity providers
- `Hr_Integration_Provider` CMDT records for SMB/Oracle vendors
- Dynamic Apex class registry fields on CMDT

---

## Appendix B — Risk register

| Risk | Mitigation |
|------|------------|
| Picklist values can't extend across packages | Move to Global Value Set early |
| `Type.forName` fails in managed package | Use fully-qualified names; document; add CI test instantiating each CMDT record |
| Core tests depend on HRIS CMDT records | Core tests use mock/stub provider classes in core test folder only |
| Coverage gate fails during split | Split CI jobs; don't block core on hris coverage |
| ADP/Oracle partner certification delays | Ship report-based fallback where possible |
| HR schedule overwrite breaks host manual edits | Document; future: `Source__c` + protect Manual windows |

---

*End of plan.*
