# Things to do next time (cal.diy scratch org)

Reference this after creating or refreshing a scratch org (`cal-diy-dev` or new alias).

## Required before full functionality

- [ ] **Set `Zoom_User_Id__c` in Scheduling Settings (Default)** — required for Server-to-Server Zoom meeting creation. Without it, token retrieval may succeed but `VideoConferencingService.createZoomMeeting` will fail.
- [ ] **Authenticate Google and Microsoft org Named Principals** — Integrations admin → Google Calendar / Microsoft Graph → Authenticate, or Setup → Named Credentials → External Credential → Permission Set Mapping for Scheduling Admin.
- [ ] **Setup → Deliverability → Access level → All Email** — required for outbound booking confirmation emails in scratch orgs.
- [ ] **Google OAuth redirect URIs** — add the new scratch org My Domain callback URL(s) to the Google Cloud OAuth client (from Integrations admin or Setup → Auth. Providers → Google Calendar Auth).

## Zoom Server-to-Server

- [ ] Create a Server-to-Server OAuth app in Zoom Marketplace with `meeting:write:meeting:admin` scope.
- [ ] Set **`Zoom_Account_Id__c`** in Scheduling Settings (Default).
- [ ] Map Client ID/Secret on **Zoom_Credential** external credential (Scheduling Admin permission set mapping), **or** configure the Zoom Auth Provider during migration.
- [ ] Set **`Zoom_User_Id__c`** (Zoom user ID meetings are created under).
- [ ] Optional: migrate Client ID/Secret fully to External Credential and retire Auth Provider fallback.

## Other integrations (as needed)

- [ ] **Stripe** — Stripe_Credential external credential + Stripe publishable key and webhook secret in Scheduling Settings.
- [ ] **Twilio** — Twilio_Credential (Account SID / Auth Token) + Twilio_API named credential.
- [ ] **Google Maps Places** — `Google_Places_API_Key__c` in Scheduling Settings.
- [ ] **Workday / HRIS** — Workday_API named credential, RaaS report paths, enable Workday HR Integration Provider; authenticate Workday_Principal ISU.

## Org setup (from scratch org skill)

- [ ] Assign **Scheduling_Host** and **Scheduling_Admin** permission sets to the admin user (done automatically by create script; verify if using manual create).
- [ ] Run **Setup Wizard** (`/lightning/n/Setup_Wizard`) — timezone, calendar connection, availability, event type; schedules background jobs (`CalDIY_CalendarSync`, `CalDIY_HrWorkforceSync`).
- [ ] Verify **Integrations** page health checks are green after the steps above.

## Quick verification commands

```bash
sf org display --target-org cal-diy-dev
sf apex run --target-org cal-diy-dev --file scripts/verify-zoom-token.apex
```

## Related docs

- Scratch org workflow: `.cursor/skills/cal-diy-scratch-org/SKILL.md`
- Integrations admin: `/lightning/n/Integrations`
