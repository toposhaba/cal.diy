# Salesforce Native Calendar Scheduling

A Salesforce-native scheduling port of Cal.DIY. Hosts define availability and event types; bookers schedule through Lightning Web Components or REST API.

## Feature Matrix

| Area | Status | Notes |
|------|--------|-------|
| Event types & availability | Implemented | Schedules, working hours, date overrides |
| Booking lifecycle | Implemented | Create, confirm, cancel, reschedule |
| Team scheduling | Implemented | Round robin, collective, managed hosts |
| Seated events | Implemented | Multi-seat slots with seat counts in UI |
| Payments | Implemented | `Pending_Payment` gate; Stripe via Named Credential |
| Video & ICS | Implemented | Auto meeting links; `.ics` on confirmation emails |
| Routing forms | Implemented | Questionnaire routes to event type; `routingForm` LWC |
| Recurring bookings | Implemented | Apex + booker UI in `calendarBooking`; series cancel in `bookingManager` |
| Calendar sync | Implemented | Google, Microsoft; batch + schedulable jobs |
| Webhooks & workflows | Implemented | Trigger-fired; admin object tabs |
| REST API | Implemented | Bookings, slots, routing, payments, recurring |
| Experience Cloud guest booking | Implemented | Community-exposed LWCs with `hostUserId`; expanded `Scheduling_Booker` perm set |

## Lightning Web Components

| Component | Purpose |
|-----------|---------|
| `calendarBooking` | Public booking flow with recurring series option |
| `routingForm` | Routing questionnaire → event type → booking |
| `bookingManager` | Host dashboard: confirm, cancel, reschedule, cancel series |
| `scheduleManager` | Availability configuration |
| `calendarConnections` | External calendar connections |
| `setupWizard` | Onboarding wizard |
| `bookingUtilityBar` | Utility bar shortcuts |

## Deployment

```bash
sf org create scratch -f config/project-scratch-def.json -a cal-diy-dev -v devOrg
sf project deploy start --source-dir force-app --test-level RunLocalTests
sf org assign permset --name Scheduling_Host
sf org assign permset --name Scheduling_Admin
```

## Security

- All Apex uses `with sharing`
- SOQL uses `WITH USER_MODE`; DML uses `as user`
- Named Credentials for external callouts
- Input validation and XSS-safe email templates
- Permission sets: `Scheduling_Host`, `Scheduling_Admin`, `Scheduling_Booker`

## Custom Objects

| Object | Purpose |
|--------|---------|
| `Schedule__c` | Working-hour templates |
| `Availability__c` | Weekly hours or date overrides |
| `Event_Type__c` | Bookable meeting definitions |
| `Booking__c` | Scheduled meetings |
| `Attendee__c` | Booking participants |
| `Booking_Seat__c` | Seated event seat reservations |
| `Calendar_Connection__c` | External calendar integrations |
| `Recurring_Pattern__c` | Recurring series configuration |
| `Routing_Form__c` | Routing questionnaire definitions |
| `Routing_Form_Field__c` | Routing form questions |
| `Routing_Form_Route__c` | Conditional routes to event types |
| `Payment__c` | Stripe payment records |
| `Team__c` / `Team_Member__c` | Team scheduling |
| `Event_Type_Host__c` | Host assignments for team types |
| `Webhook__c` | Outbound webhook subscriptions |
| `Workflow__c` / `Workflow_Step__c` | Automated workflow actions |
| `Out_of_Office__c` | Host unavailability |
| `Booking_Field__c` / `Booking_Field_Set__c` | Custom booking fields |
| `Scheduling_Config__mdt` | Admin defaults (Custom Metadata) |
| `Booking_Event__e` | Platform Event for integrations |

## REST API

Base URL: `/services/apexrest/scheduling/v1`

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/event-types?hostUserId=...` | List active event types |
| GET | `/slots?eventTypeId=...&startDate=...&endDate=...` | Available time slots (includes seat counts) |
| GET | `/routing-forms?hostUserId=...` | List routing forms for a host |
| GET | `/routing-forms/:id/fields` | Routing form questions |
| POST | `/routing-forms/:id/evaluate` | Evaluate answers and get target event type |
| GET | `/bookings/:uid` | Get booking by UID |
| POST | `/bookings` | Create a booking |
| POST | `/bookings/recurring` | Create a recurring series |
| POST | `/bookings/:uid/cancel` | Cancel a booking |
| POST | `/bookings/:uid/confirm` | Confirm a pending booking |
| POST | `/bookings/:uid/payment-intent` | Create Stripe payment intent |
| POST | `/bookings/:uid/complete-payment` | Capture payment and confirm booking |
| PATCH | `/bookings/:uid/reschedule` | Reschedule a booking |
| POST | `/webhooks/stripe` | Stripe payment webhook |

## Experience Cloud

1. Create a Digital Experience site and assign the **Scheduling_Booker** permission set to the guest user profile.
2. Add the `calendarBooking` or `routingForm` component to a community page.
3. Set the **Host User ID** design property to the Salesforce User Id of the host being booked.

Routing forms are also available via `SchedulingController` Apex methods and the `routingForm` LWC.

## Permission Sets

| Permission Set | Target Users |
|----------------|--------------|
| `Scheduling_Admin` | Full admin access |
| `Scheduling_Host` | Host scheduling operations |
| `Scheduling_Booker` | Read event types, create bookings |

## License

See [LICENSE](LICENSE) for details.
