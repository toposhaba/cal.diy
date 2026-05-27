import { LightningElement, track } from 'lwc';
import getMySchedules from '@salesforce/apex/SchedulingController.getMySchedules';
import createSchedule from '@salesforce/apex/SchedulingController.createSchedule';
import addAvailability from '@salesforce/apex/SchedulingController.addAvailability';

export default class ScheduleManager extends LightningElement {
    @track schedules = [];
    @track isLoading = false;
    @track error;
    @track showNewScheduleForm = false;
    @track showAddAvailabilityForm = false;
    @track selectedScheduleId;

    newScheduleName = '';
    newScheduleTimeZone = '';
    newScheduleIsDefault = false;

    availabilityType = 'Working_Hours';
    availabilityDays = '';
    availabilityStartTime = '';
    availabilityEndTime = '';
    availabilityOverrideDate = '';

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

    get typeOptions() {
        return [
            { label: 'Working Hours', value: 'Working_Hours' },
            { label: 'Date Override', value: 'Date_Override' }
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

    get isWorkingHoursType() {
        return this.availabilityType === 'Working_Hours';
    }

    get isDateOverrideType() {
        return this.availabilityType === 'Date_Override';
    }

    get hasSchedules() {
        return this.schedules && this.schedules.length > 0;
    }

    get noSchedules() {
        return !this.hasSchedules;
    }

    get notLoading() {
        return !this.isLoading;
    }

    connectedCallback() {
        this.loadSchedules();
    }

    async loadSchedules() {
        this.isLoading = true;
        this.error = undefined;
        try {
            const raw = await getMySchedules();
            this.schedules = raw.map(s => ({
                ...s,
                Availabilities__r: s.Availabilities__r
                    ? s.Availabilities__r.map(a => ({
                          ...a,
                          formattedStartTime: this.formatTimeMs(a.Start_Time__c),
                          formattedEndTime: this.formatTimeMs(a.End_Time__c)
                      }))
                    : null
            }));
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    formatTimeMs(ms) {
        if (ms == null) return '';
        const totalMinutes = Math.floor(ms / 60000);
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;
        const period = hours >= 12 ? 'PM' : 'AM';
        const displayHour = hours % 12 || 12;
        return `${displayHour}:${String(minutes).padStart(2, '0')} ${period}`;
    }

    handleNewScheduleClick() {
        this.showNewScheduleForm = true;
    }

    handleScheduleNameChange(event) {
        this.newScheduleName = event.target.value;
    }

    handleTimeZoneChange(event) {
        this.newScheduleTimeZone = event.detail.value;
    }

    handleIsDefaultChange(event) {
        this.newScheduleIsDefault = event.target.checked;
    }

    async handleCreateSchedule() {
        if (!this.newScheduleName || !this.newScheduleTimeZone) {
            this.error = 'Name and timezone are required';
            return;
        }

        this.isLoading = true;
        this.error = undefined;
        try {
            await createSchedule({
                name: this.newScheduleName,
                timeZone: this.newScheduleTimeZone,
                isDefault: this.newScheduleIsDefault
            });
            this.showNewScheduleForm = false;
            this.newScheduleName = '';
            this.newScheduleTimeZone = '';
            this.newScheduleIsDefault = false;
            await this.loadSchedules();
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleCancelNewSchedule() {
        this.showNewScheduleForm = false;
    }

    handleAddAvailabilityClick(event) {
        this.selectedScheduleId = event.currentTarget.dataset.id;
        this.showAddAvailabilityForm = true;
    }

    handleAvailabilityTypeChange(event) {
        this.availabilityType = event.detail.value;
    }

    handleDaysChange(event) {
        this.availabilityDays = event.detail.value.join(';');
    }

    handleAvailStartTimeChange(event) {
        this.availabilityStartTime = event.target.value;
    }

    handleAvailEndTimeChange(event) {
        this.availabilityEndTime = event.target.value;
    }

    handleOverrideDateChange(event) {
        this.availabilityOverrideDate = event.target.value;
    }

    async handleSaveAvailability() {
        if (!this.availabilityStartTime || !this.availabilityEndTime) {
            this.error = 'Start and end times are required';
            return;
        }

        this.isLoading = true;
        this.error = undefined;
        try {
            await addAvailability({
                scheduleId: this.selectedScheduleId,
                recordType: this.availabilityType,
                days: this.availabilityDays,
                startTimeStr: this.availabilityStartTime,
                endTimeStr: this.availabilityEndTime,
                overrideDateStr: this.availabilityOverrideDate
            });
            this.showAddAvailabilityForm = false;
            this.resetAvailabilityForm();
            await this.loadSchedules();
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleCancelAddAvailability() {
        this.showAddAvailabilityForm = false;
        this.resetAvailabilityForm();
    }

    resetAvailabilityForm() {
        this.availabilityType = 'Working_Hours';
        this.availabilityDays = '';
        this.availabilityStartTime = '';
        this.availabilityEndTime = '';
        this.availabilityOverrideDate = '';
    }

    extractError(err) {
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'An unexpected error occurred';
    }
}
