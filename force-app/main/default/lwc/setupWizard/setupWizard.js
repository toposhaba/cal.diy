import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import userTimeZone from '@salesforce/i18n/timeZone';
import getOnboardingStatus from '@salesforce/apex/SchedulingController.getOnboardingStatus';
import createSchedule from '@salesforce/apex/SchedulingController.createSchedule';
import addAvailability from '@salesforce/apex/SchedulingController.addAvailability';
import createEventType from '@salesforce/apex/SchedulingController.createEventType';
import scheduleBackgroundJobs from '@salesforce/apex/SchedulingController.scheduleBackgroundJobs';
import createConnection from '@salesforce/apex/CalendarConnectionController.createConnection';
import getNamedCredentialAuthUrl from '@salesforce/apex/CalendarConnectionController.getNamedCredentialAuthUrl';
import verifyConnection from '@salesforce/apex/CalendarConnectionController.verifyConnection';
import isSchedulingAdminUser from '@salesforce/apex/CalendarConnectionController.isSchedulingAdminUser';
import getMySchedules from '@salesforce/apex/SchedulingController.getMySchedules';
import getActiveEventTypes from '@salesforce/apex/SchedulingController.getActiveEventTypes';

export default class SetupWizard extends NavigationMixin(LightningElement) {
    @track currentStep = 'loading';
    @track isLoading = true;
    @track error;
    @track onboardingStatus = {};
    @track orgAuthStatus = '';
    @track orgAuthMessage = '';
    @track orgAuthIntegrationsUrl = '';
    @track showOrgAuthNotice = false;
    @track showAdminOAuthFlow = false;
    @track oauthAuthUrl = '';
    @track oauthSetupUrl = '';
    @track oauthNotConfigured = false;
    @track oauthSetupMessage = '';
    @track isSchedulingAdmin = false;

    selectedTimeZone;

    calendarProvider = '';
    calendarId = '';
    calendarCheckConflicts = true;
    calendarPushEvents = false;

    scheduleName = 'Default';
    availabilityDays = 'Monday;Tuesday;Wednesday;Thursday;Friday';
    availabilityStartTime = '09:00';
    availabilityEndTime = '17:00';

    eventTypeName = '30 Minute Meeting';
    eventTypeDuration = 30;
    eventTypeDescription = '';

    @track dashboardData = {};

    @wire(isSchedulingAdminUser)
    wiredIsSchedulingAdmin({ data }) {
        this.isSchedulingAdmin = data === true;
    }

    get steps() {
        return [
            { label: 'Timezone', value: 'timezone' },
            { label: 'Calendar', value: 'calendar' },
            { label: 'Availability', value: 'availability' },
            { label: 'Event Type', value: 'event-type' }
        ];
    }

    get timezoneOptions() {
        return [
            { label: 'Pacific/Honolulu (HST, UTC-10)', value: 'Pacific/Honolulu' },
            { label: 'America/Anchorage (AKST, UTC-9)', value: 'America/Anchorage' },
            { label: 'America/Los_Angeles (PT, UTC-8)', value: 'America/Los_Angeles' },
            { label: 'America/Phoenix (MST, UTC-7)', value: 'America/Phoenix' },
            { label: 'America/Denver (MT, UTC-7)', value: 'America/Denver' },
            { label: 'America/Chicago (CT, UTC-6)', value: 'America/Chicago' },
            { label: 'America/New_York (ET, UTC-5)', value: 'America/New_York' },
            { label: 'America/Halifax (AT, UTC-4)', value: 'America/Halifax' },
            { label: 'America/St_Johns (NT, UTC-3:30)', value: 'America/St_Johns' },
            { label: 'America/Sao_Paulo (BRT, UTC-3)', value: 'America/Sao_Paulo' },
            { label: 'America/Argentina/Buenos_Aires (ART, UTC-3)', value: 'America/Argentina/Buenos_Aires' },
            { label: 'Atlantic/Cape_Verde (CVT, UTC-1)', value: 'Atlantic/Cape_Verde' },
            { label: 'Europe/London (GMT, UTC+0)', value: 'Europe/London' },
            { label: 'Europe/Paris (CET, UTC+1)', value: 'Europe/Paris' },
            { label: 'Europe/Berlin (CET, UTC+1)', value: 'Europe/Berlin' },
            { label: 'Europe/Amsterdam (CET, UTC+1)', value: 'Europe/Amsterdam' },
            { label: 'Africa/Lagos (WAT, UTC+1)', value: 'Africa/Lagos' },
            { label: 'Europe/Athens (EET, UTC+2)', value: 'Europe/Athens' },
            { label: 'Africa/Cairo (EET, UTC+2)', value: 'Africa/Cairo' },
            { label: 'Europe/Helsinki (EET, UTC+2)', value: 'Europe/Helsinki' },
            { label: 'Europe/Istanbul (TRT, UTC+3)', value: 'Europe/Istanbul' },
            { label: 'Europe/Moscow (MSK, UTC+3)', value: 'Europe/Moscow' },
            { label: 'Asia/Dubai (GST, UTC+4)', value: 'Asia/Dubai' },
            { label: 'Asia/Karachi (PKT, UTC+5)', value: 'Asia/Karachi' },
            { label: 'Asia/Kolkata (IST, UTC+5:30)', value: 'Asia/Kolkata' },
            { label: 'Asia/Dhaka (BST, UTC+6)', value: 'Asia/Dhaka' },
            { label: 'Asia/Bangkok (ICT, UTC+7)', value: 'Asia/Bangkok' },
            { label: 'Asia/Singapore (SGT, UTC+8)', value: 'Asia/Singapore' },
            { label: 'Asia/Shanghai (CST, UTC+8)', value: 'Asia/Shanghai' },
            { label: 'Asia/Hong_Kong (HKT, UTC+8)', value: 'Asia/Hong_Kong' },
            { label: 'Asia/Tokyo (JST, UTC+9)', value: 'Asia/Tokyo' },
            { label: 'Asia/Seoul (KST, UTC+9)', value: 'Asia/Seoul' },
            { label: 'Australia/Adelaide (ACST, UTC+9:30)', value: 'Australia/Adelaide' },
            { label: 'Australia/Sydney (AEST, UTC+10)', value: 'Australia/Sydney' },
            { label: 'Australia/Brisbane (AEST, UTC+10)', value: 'Australia/Brisbane' },
            { label: 'Pacific/Auckland (NZST, UTC+12)', value: 'Pacific/Auckland' }
        ];
    }

    get providerOptions() {
        return [
            { label: 'Google Calendar', value: 'Google' },
            { label: 'Microsoft Outlook', value: 'Microsoft' },
            { label: 'Salesforce Events', value: 'Salesforce' }
        ];
    }

    get dayOptions() {
        return [
            { label: 'Monday', value: 'Monday' },
            { label: 'Tuesday', value: 'Tuesday' },
            { label: 'Wednesday', value: 'Wednesday' },
            { label: 'Thursday', value: 'Thursday' },
            { label: 'Friday', value: 'Friday' },
            { label: 'Saturday', value: 'Saturday' },
            { label: 'Sunday', value: 'Sunday' }
        ];
    }

    get selectedDaysArray() {
        return this.availabilityDays ? this.availabilityDays.split(';') : [];
    }

    get isTimezoneStep() { return this.currentStep === 'timezone'; }
    get isCalendarStep() { return this.currentStep === 'calendar'; }
    get isAvailabilityStep() { return this.currentStep === 'availability'; }
    get isEventTypeStep() { return this.currentStep === 'event-type'; }
    get isDashboard() { return this.currentStep === 'dashboard'; }
    get isWizard() { return !this.isDashboard && this.currentStep !== 'loading'; }
    get requiresOrgAuth() { return this.calendarProvider === 'Google' || this.calendarProvider === 'Microsoft'; }
    get isSalesforceProvider() { return this.calendarProvider === 'Salesforce'; }
    get notShowingOrgAuthNotice() { return !this.showOrgAuthNotice; }
    get showingAdminOAuthFlow() { return this.showAdminOAuthFlow; }
    get notShowingAdminOAuthFlow() { return !this.showAdminOAuthFlow; }
    get showingDashboardAdminAuth() { return this.isDashboard && this.isSchedulingAdmin && !this.showAdminOAuthFlow; }
    get showingDashboardAdminOAuthFlow() { return this.isDashboard && this.showAdminOAuthFlow; }

    get calendarProviderLabel() {
        return this.getProviderLabel(this.calendarProvider);
    }

    get configureOAuthHeading() {
        return `Configure ${this.calendarProviderLabel} OAuth First`;
    }

    get authenticateCalendarHeading() {
        return `Authenticate ${this.calendarProviderLabel} (Admin)`;
    }

    getProviderLabel(provider) {
        const map = { Google: 'Google Calendar', Microsoft: 'Microsoft Outlook', Salesforce: 'Salesforce Events' };
        return map[provider] || provider;
    }

    connectedCallback() {
        this.selectedTimeZone = this.resolveDefaultTimeZone();
        this.checkStatus();
    }

    resolveDefaultTimeZone() {
        const match = this.timezoneOptions.find((option) => option.value === userTimeZone);
        return match ? match.value : 'America/New_York';
    }

    async checkStatus() {
        this.isLoading = true;
        this.error = undefined;
        try {
            this.onboardingStatus = await getOnboardingStatus();
            if (this.onboardingStatus.hasSchedule &&
                this.onboardingStatus.hasAvailability &&
                this.onboardingStatus.hasEventType) {
                await this.loadDashboard();
                this.currentStep = 'dashboard';
            } else {
                this.currentStep = 'timezone';
            }
        } catch (err) {
            this.error = this.extractError(err);
            this.currentStep = 'timezone';
        } finally {
            this.isLoading = false;
        }
    }

    async loadDashboard() {
        try {
            const schedules = await getMySchedules();
            const eventTypes = await getActiveEventTypes({ hostUserId: null });
            this.dashboardData = {
                scheduleCount: schedules.length,
                eventTypeCount: eventTypes.length,
                timezone: schedules.length > 0 ? schedules[0].Time_Zone__c : 'Not set',
                hasCalendar: this.onboardingStatus.hasCalendarConnection
            };
        } catch (err) {
            this.dashboardData = { scheduleCount: 0, eventTypeCount: 0, timezone: 'Unknown', hasCalendar: false };
        }
    }

    handleTimezoneChange(event) {
        this.selectedTimeZone = event.detail.value;
    }

    handleNextFromTimezone() {
        this.currentStep = 'calendar';
    }

    handleProviderChange(event) {
        this.calendarProvider = event.detail.value;
        this.resetOrgAuthState();
    }

    handleCalendarIdChange(event) {
        this.calendarId = event.target.value;
    }

    handleCheckConflictsChange(event) {
        this.calendarCheckConflicts = event.target.checked;
    }

    handlePushEventsChange(event) {
        this.calendarPushEvents = event.target.checked;
    }

    resetOrgAuthState() {
        this.showOrgAuthNotice = false;
        this.showAdminOAuthFlow = false;
        this.orgAuthStatus = '';
        this.orgAuthMessage = '';
        this.orgAuthIntegrationsUrl = '';
        this.oauthAuthUrl = '';
        this.oauthSetupUrl = '';
        this.oauthNotConfigured = false;
        this.oauthSetupMessage = '';
    }

    async handleConnectCalendar() {
        if (!this.calendarProvider) {
            this.error = 'Please select a calendar provider';
            return;
        }

        if (this.calendarProvider === 'Salesforce') {
            await this.saveCalendarConnection();
            return;
        }

        this.isLoading = true;
        this.error = undefined;
        this.resetOrgAuthState();
        try {
            const verifyResult = await verifyConnection({ provider: this.calendarProvider });
            if (verifyResult.authenticated) {
                await this.saveCalendarConnection();
                return;
            }

            if (this.isSchedulingAdmin) {
                await this.startAdminOAuthFlow(this.calendarProvider);
                return;
            }

            this.showOrgAuthNotice = true;
            this.orgAuthStatus = 'admin_required';
            this.orgAuthMessage = verifyResult.message ||
                'Your Scheduling Admin must authenticate Google or Microsoft in Integrations before you can connect a calendar.';
            this.orgAuthIntegrationsUrl = '/lightning/n/Integrations';
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    async saveCalendarConnection() {
        this.isLoading = true;
        this.error = undefined;
        try {
            await createConnection({
                provider: this.calendarProvider,
                calendarId: this.calendarId,
                checkConflicts: this.calendarCheckConflicts,
                pushEvents: this.calendarPushEvents
            });
            this.resetOrgAuthState();
            if (this.isCalendarStep) {
                this.currentStep = 'availability';
            } else if (this.isDashboard) {
                await this.loadDashboard();
            }
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    async startAdminOAuthFlow(provider) {
        this.calendarProvider = provider;
        this.showAdminOAuthFlow = true;
        this.oauthNotConfigured = false;
        this.oauthSetupMessage = '';
        this.oauthSetupUrl = '';
        this.oauthAuthUrl = '';
        try {
            const authInfo = await getNamedCredentialAuthUrl({
                provider,
                returnPageApiName: 'Integrations'
            });
            this.oauthNotConfigured = authInfo.type === 'oauth_not_configured';
            this.oauthSetupMessage = authInfo.message || '';
            this.oauthSetupUrl = authInfo.setupUrl || '';
            this.oauthAuthUrl = authInfo.authUrl || '';
        } catch (err) {
            this.error = this.extractError(err);
            this.showAdminOAuthFlow = false;
        }
    }

    handleAuthenticateGoogleAdmin() {
        this.startAdminOAuthFlow('Google');
    }

    handleAuthenticateMicrosoftAdmin() {
        this.startAdminOAuthFlow('Microsoft');
    }

    handleCancelAdminAuth() {
        this.resetOrgAuthState();
        this.error = undefined;
    }

    handleAuthorizeOAuth() {
        if (this.oauthNotConfigured) {
            this.error = this.oauthSetupMessage || 'OAuth is not configured yet. Configure the Auth Provider in Setup first.';
            return;
        }
        if (this.oauthAuthUrl) {
            const popup = window.open(
                this.oauthAuthUrl,
                'calDiyOAuth',
                'width=600,height=700,menubar=no,toolbar=no,location=yes,status=yes,resizable=yes,scrollbars=yes'
            );
            if (!popup || popup.closed || typeof popup.closed === 'undefined') {
                this.error = 'Popup blocked. Allow popups for this site, then try again.';
                return;
            }
            popup.focus();
        }
    }

    handleOpenOAuthSetup() {
        if (this.oauthSetupUrl) {
            window.open(this.oauthSetupUrl, '_blank');
        }
    }

    handleOpenIntegrations() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'Integrations' }
        });
    }

    async handleVerifyOAuth() {
        this.isLoading = true;
        this.error = undefined;
        try {
            const result = await verifyConnection({ provider: this.calendarProvider });
            if (result.authenticated) {
                this.resetOrgAuthState();
                if (this.isCalendarStep) {
                    await this.saveCalendarConnection();
                } else if (this.isDashboard) {
                    await this.loadDashboard();
                }
            } else {
                this.error = result.message;
            }
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleSkipOrgAuth() {
        this.resetOrgAuthState();
        this.currentStep = 'availability';
    }

    handleSkipCalendar() {
        this.currentStep = 'availability';
    }

    handleScheduleNameChange(event) {
        this.scheduleName = event.target.value;
    }

    handleDaysChange(event) {
        this.availabilityDays = event.detail.value.join(';');
    }

    handleStartTimeChange(event) {
        this.availabilityStartTime = event.target.value;
    }

    handleEndTimeChange(event) {
        this.availabilityEndTime = event.target.value;
    }

    async handleCreateSchedule() {
        if (!this.scheduleName || !this.availabilityDays || !this.availabilityStartTime || !this.availabilityEndTime) {
            this.error = 'Please fill in all availability fields';
            return;
        }
        this.isLoading = true;
        this.error = undefined;
        try {
            const schedule = await createSchedule({
                name: this.scheduleName,
                timeZone: this.selectedTimeZone,
                isDefault: true
            });
            await addAvailability({
                scheduleId: schedule.Id,
                recordType: 'Working_Hours',
                days: this.availabilityDays,
                startTimeStr: this.availabilityStartTime,
                endTimeStr: this.availabilityEndTime,
                overrideDateStr: ''
            });
            this.currentStep = 'event-type';
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleEventTypeNameChange(event) {
        this.eventTypeName = event.target.value;
    }

    handleEventTypeDurationChange(event) {
        this.eventTypeDuration = parseInt(event.target.value, 10);
    }

    handleEventTypeDescriptionChange(event) {
        this.eventTypeDescription = event.target.value;
    }

    async handleCreateEventType() {
        if (!this.eventTypeName || !this.eventTypeDuration) {
            this.error = 'Name and duration are required';
            return;
        }
        this.isLoading = true;
        this.error = undefined;
        try {
            await createEventType({
                name: this.eventTypeName,
                durationMinutes: this.eventTypeDuration,
                description: this.eventTypeDescription
            });
            await scheduleBackgroundJobs();
            this.onboardingStatus.hasSchedule = true;
            this.onboardingStatus.hasAvailability = true;
            this.onboardingStatus.hasEventType = true;
            await this.loadDashboard();
            this.currentStep = 'dashboard';
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleBackToTimezone() {
        this.error = undefined;
        this.currentStep = 'timezone';
    }

    handleBackToCalendar() {
        this.error = undefined;
        this.currentStep = 'calendar';
    }

    handleBackToAvailability() {
        this.error = undefined;
        this.currentStep = 'availability';
    }

    handleRestartWizard() {
        this.selectedTimeZone = this.resolveDefaultTimeZone();
        this.currentStep = 'timezone';
    }

    handleOpenBookingPage() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'Calendar_Booking' }
        });
    }

    handleOpenScheduleManager() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'Schedule_Manager' }
        });
    }

    handleOpenBookingManager() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'Booking_Manager' }
        });
    }

    handleOpenCalendarConnections() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'Calendar_Connections' }
        });
    }

    extractError(err) {
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'An unexpected error occurred';
    }
}
