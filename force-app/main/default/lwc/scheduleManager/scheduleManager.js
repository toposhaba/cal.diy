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
            { label: 'America/New_York (ET)', value: 'America/New_York' },
            { label: 'America/Chicago (CT)', value: 'America/Chicago' },
            { label: 'America/Denver (MT)', value: 'America/Denver' },
            { label: 'America/Los_Angeles (PT)', value: 'America/Los_Angeles' },
            { label: 'Europe/London (GMT)', value: 'Europe/London' },
            { label: 'Europe/Paris (CET)', value: 'Europe/Paris' },
            { label: 'Asia/Tokyo (JST)', value: 'Asia/Tokyo' },
            { label: 'Australia/Sydney (AEST)', value: 'Australia/Sydney' }
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

    connectedCallback() {
        this.loadSchedules();
    }

    async loadSchedules() {
        this.isLoading = true;
        this.error = undefined;
        try {
            this.schedules = await getMySchedules();
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
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
