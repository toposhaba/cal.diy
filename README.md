# Salesforce Native Calendar Scheduling

A feature-complete calendar scheduling solution built natively on the Salesforce platform. Enables hosts to define their availability and allows bookers to schedule meetings through Lightning Web Components or REST API.

## Features

- **Event Types** — Define bookable meeting templates with duration, buffers, and booking rules
- **Availability Management** — Recurring weekly hours and date-specific overrides
- **Booking Lifecycle** — Create, confirm, cancel, and reschedule with validation
- **Recurring Bookings** — Daily, weekly, biweekly, and monthly series
- **Calendar Integration** — Sync with Google Calendar and Microsoft Outlook via Named Credentials
- **Conflict Detection** — Checks internal bookings + external calendar busy times
- **Email Notifications** — Automatic HTML emails for all booking lifecycle events
- **Platform Events** — Real-time event bus for downstream integrations
- **REST API** — Full CRUD endpoint for external systems
- **Batch Sync** — Schedulable job for periodic calendar synchronization

## Project Structure

```
force-app/main/default/
├── classes/                    # Apex classes and test classes
├── lwc/                        # Lightning Web Components
│   ├── calendarBooking/        # Public booking flow
│   ├── bookingManager/         # Host booking dashboard
│   ├── scheduleManager/        # Availability configuration
│   └── calendarConnections/    # Calendar integration management
├── objects/                    # Custom objects and fields
├── triggers/                   # Apex triggers
├── namedCredentials/           # Google Calendar & Microsoft Graph
├── externalCredentials/        # OAuth 2.0 configurations
├── permissionsets/             # Host, Booker, Admin permission sets
├── labels/                     # Custom Labels for i18n
├── customMetadata/             # Scheduling configuration defaults
└── platformEvents/             # Booking_Event__e
```

## Deployment

```bash
# Deploy to a scratch org
sf org create scratch -f config/project-scratch-def.json -a scheduling-dev
sf project deploy start --source-dir force-app

# Run all tests
sf apex run test --test-level RunLocalTests --wait 10

# Assign permission set
sf org assign permset --name Scheduling_Host
```

## Security

This solution is designed to pass Salesforce security review:

- All Apex classes use `with sharing`
- All SOQL queries enforce CRUD/FLS via `WITH USER_MODE`
- All DML uses `as user` syntax
- Named Credentials for all external callouts (no stored secrets)
- Input validation on all user-supplied data
- XSS prevention in email templates
- Bind variables in all queries (no SOQL injection)
- Permission sets follow principle of least privilege
- Private sharing model on all custom objects

## Custom Objects

| Object | Purpose |
|--------|---------|
| `Schedule__c` | Named working-hour templates |
| `Availability__c` | Time windows (weekly hours or date overrides) |
| `Event_Type__c` | Bookable meeting definitions |
| `Booking__c` | Scheduled meeting records |
| `Attendee__c` | Booking participants |
| `Calendar_Connection__c` | External calendar integrations |
| `Recurring_Pattern__c` | Recurring series configuration |
| `Scheduling_Config__mdt` | Admin configuration (Custom Metadata) |
| `Booking_Event__e` | Real-time Platform Event |

## REST API

Base URL: `/services/apexrest/scheduling/v1`

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/event-types?hostUserId=...` | List active event types |
| GET | `/slots?eventTypeId=...&startDate=...&endDate=...` | Get available time slots |
| GET | `/bookings/:uid` | Get booking by UID |
| POST | `/bookings` | Create a booking |
| POST | `/bookings/:uid/cancel` | Cancel a booking |
| PATCH | `/bookings/:uid/reschedule` | Reschedule a booking |

## Permission Sets

| Permission Set | Target Users | Access Level |
|---------------|--------------|--------------|
| `Scheduling_Admin` | Administrators | Full CRUD + ViewAll/ModifyAll |
| `Scheduling_Host` | Meeting hosts | CRUD on own records |
| `Scheduling_Booker` | Internal/community bookers | Read event types, create bookings |

## License

See [LICENSE](LICENSE) for details.
