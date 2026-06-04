import { LightningElement, api, track } from 'lwc';
import getActiveEventTypes from '@salesforce/apex/SchedulingController.getActiveEventTypes';
import getAvailableSlots from '@salesforce/apex/SchedulingController.getAvailableSlots';
import createBooking from '@salesforce/apex/SchedulingController.createBooking';
import createBookingWithFields from '@salesforce/apex/SchedulingController.createBookingWithFields';
import createRecurringSeries from '@salesforce/apex/SchedulingController.createRecurringSeries';
import getBookingFormFields from '@salesforce/apex/SchedulingController.getBookingFormFields';

export default class CalendarBooking extends LightningElement {
    @api hostUserId;
    @track eventTypes = [];
    @track availableSlots = [];
    @track selectedEventType;
    @track selectedDate;
    @track selectedSlot;
    @track bookerName = '';
    @track bookerEmail = '';
    @track formFields = [];
    @track fieldValues = {};
    @track isLoading = false;
    @track error;
    @track bookingConfirmed = false;
    @track confirmedBooking;
    @track currentStep = 'event-type';
    @track isRecurring = false;
    @track recurringFrequency = 'Weekly';
    @track recurringOccurrences = 4;

    connectedCallback() {
        this.loadEventTypes();
        this.loadFormFields();
    }

    async loadFormFields() {
        try {
            this.formFields = await getBookingFormFields();
        } catch (err) {
            this.formFields = [];
        }
    }

    get hasFieldSet() {
        return this.formFields && this.formFields.length > 0;
    }

    get renderableFields() {
        return this.formFields.map(f => ({
            ...f,
            isLookup: f.type === 'REFERENCE',
            isEmail: f.type === 'EMAIL',
            isText: f.type === 'STRING' || f.type === 'TEXT',
            isTextArea: f.type === 'TEXTAREA',
            isPhone: f.type === 'PHONE',
            isNumber: f.type === 'DOUBLE' || f.type === 'INTEGER' || f.type === 'CURRENCY',
            isCheckbox: f.type === 'BOOLEAN',
            isDate: f.type === 'DATE',
            isDateTime: f.type === 'DATETIME',
            isContactLookup: f.apiName === 'Booker_Contact__c',
            isRequired: f.required === 'true',
            value: this.fieldValues[f.apiName] || ''
        }));
    }

    handleFieldChange(event) {
        const fieldName = event.target.dataset.field;
        this.fieldValues = { ...this.fieldValues, [fieldName]: event.target.value };
        if (fieldName === 'Booker_Name__c') {
            this.bookerName = event.target.value;
        }
        if (fieldName === 'Booker_Email__c') {
            this.bookerEmail = event.target.value;
        }
    }

    handleContactSelect(event) {
        const selectedId = event.detail.value && event.detail.value.length > 0 ? event.detail.value[0] : null;
        this.fieldValues = { ...this.fieldValues, Booker_Contact__c: selectedId };
    }

    async loadEventTypes() {
        this.isLoading = true;
        this.error = undefined;
        try {
            this.eventTypes = await getActiveEventTypes({ hostUserId: this.hostUserId });
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleEventTypeSelect(event) {
        const eventTypeId = event.currentTarget.dataset.id;
        this.selectedEventType = this.eventTypes.find(et => et.Id === eventTypeId);
        this.currentStep = 'date-select';
        this.loadSlotsForWeek();
    }

    handleDateChange(event) {
        this.selectedDate = event.target.value;
        this.selectedSlot = null;
        this.loadSlotsForDate();
    }

    async loadSlotsForWeek() {
        const today = new Date();
        this.selectedDate = today.toISOString().split('T')[0];
        await this.loadSlotsForDate();
    }

    async loadSlotsForDate() {
        if (!this.selectedEventType || !this.selectedDate) return;

        this.isLoading = true;
        this.error = undefined;
        try {
            const startDate = this.selectedDate;
            const endDate = this.selectedDate;
            this.availableSlots = await getAvailableSlots({
                eventTypeId: this.selectedEventType.Id,
                startDateStr: startDate,
                endDateStr: endDate
            });
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleSlotSelect(event) {
        const slotIndex = parseInt(event.currentTarget.dataset.index, 10);
        this.selectedSlot = this.availableSlots[slotIndex];
        this.currentStep = 'booking-form';
    }

    handleNameChange(event) {
        this.bookerName = event.target.value;
    }

    handleEmailChange(event) {
        this.bookerEmail = event.target.value;
    }

    handleRecurringChange(event) {
        this.isRecurring = event.target.checked;
    }

    handleFrequencyChange(event) {
        this.recurringFrequency = event.detail.value;
    }

    handleOccurrencesChange(event) {
        this.recurringOccurrences = parseInt(event.target.value, 10);
    }

    async handleBookingSubmit() {
        if (!this.validateForm()) return;

        this.isLoading = true;
        this.error = undefined;
        try {
            if (this.hasFieldSet) {
                const values = { ...this.fieldValues };
                if (!values.Booker_Name__c) values.Booker_Name__c = this.bookerName;
                if (!values.Booker_Email__c) values.Booker_Email__c = this.bookerEmail;
                this.confirmedBooking = await createBookingWithFields({
                    eventTypeId: this.selectedEventType.Id,
                    startDateTimeStr: this.selectedSlot.startTime,
                    fieldValues: values
                });
            } else if (this.isRecurring) {
                const bookings = await createRecurringSeries({
                    eventTypeId: this.selectedEventType.Id,
                    firstStartDateTimeStr: this.selectedSlot.startTime,
                    bookerEmail: this.bookerEmail,
                    bookerName: this.bookerName,
                    frequency: this.recurringFrequency,
                    occurrences: this.recurringOccurrences,
                    seriesEndDateStr: null
                });
                this.confirmedBooking = bookings[0];
            } else {
                this.confirmedBooking = await createBooking({
                    eventTypeId: this.selectedEventType.Id,
                    startDateTimeStr: this.selectedSlot.startTime,
                    bookerEmail: this.bookerEmail,
                    bookerName: this.bookerName,
                    attendeeEmails: []
                });
            }
            this.bookingConfirmed = true;
            this.currentStep = 'confirmation';
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleBack() {
        if (this.currentStep === 'booking-form') {
            this.currentStep = 'date-select';
            this.selectedSlot = null;
        } else if (this.currentStep === 'date-select') {
            this.currentStep = 'event-type';
            this.selectedEventType = null;
            this.availableSlots = [];
        }
    }

    handleStartOver() {
        this.currentStep = 'event-type';
        this.selectedEventType = null;
        this.selectedDate = null;
        this.selectedSlot = null;
        this.bookerName = '';
        this.bookerEmail = '';
        this.bookingConfirmed = false;
        this.confirmedBooking = null;
        this.isRecurring = false;
        this.recurringFrequency = 'Weekly';
        this.recurringOccurrences = 4;
        this.error = undefined;
    }

    validateForm() {
        const inputs = this.template.querySelectorAll('lightning-input');
        let isValid = true;
        inputs.forEach(input => {
            if (!input.checkValidity()) {
                input.reportValidity();
                isValid = false;
            }
        });
        return isValid;
    }

    get isEventTypeStep() {
        return this.currentStep === 'event-type';
    }

    get isDateSelectStep() {
        return this.currentStep === 'date-select';
    }

    get isBookingFormStep() {
        return this.currentStep === 'booking-form';
    }

    get isConfirmationStep() {
        return this.currentStep === 'confirmation';
    }

    get isPendingBooking() {
        return this.confirmedBooking && this.confirmedBooking.Status__c === 'Pending';
    }

    get isPendingPayment() {
        return this.confirmedBooking && this.confirmedBooking.Status__c === 'Pending_Payment';
    }

    get confirmationHeading() {
        if (this.isPendingPayment) {
            return 'Payment Required';
        }
        if (this.isRecurring && this.bookingConfirmed) {
            return 'Recurring Series Booked!';
        }
        return this.isPendingBooking ? 'Booking Pending Approval' : 'Booking Confirmed!';
    }

    get frequencyOptions() {
        return [
            { label: 'Weekly', value: 'Weekly' },
            { label: 'Biweekly', value: 'Biweekly' },
            { label: 'Daily', value: 'Daily' },
            { label: 'Monthly', value: 'Monthly' }
        ];
    }

    get confirmationIcon() {
        if (this.isPendingPayment) {
            return 'utility:money';
        }
        return this.isPendingBooking ? 'action:submit_for_approval' : 'action:approval';
    }

    get hasSlots() {
        return this.availableSlots && this.availableSlots.length > 0;
    }

    get noSlots() {
        return !this.hasSlots;
    }

    get notLoading() {
        return !this.isLoading;
    }

    get formattedSlots() {
        return this.availableSlots.map((slot, index) => {
            const formattedTime = this.formatTime(slot.startTime);
            const slotLabel = slot.availableSeats > 1
                ? `${formattedTime} (${slot.availableSeats} seats)`
                : formattedTime;
            return {
                ...slot,
                index,
                formattedTime,
                slotLabel
            };
        });
    }

    get minDate() {
        return new Date().toISOString().split('T')[0];
    }

    get maxDate() {
        const max = new Date();
        max.setDate(max.getDate() + 60);
        return max.toISOString().split('T')[0];
    }

    get selectedSlotFormatted() {
        if (!this.selectedSlot) return '';
        return this.formatDateTime(this.selectedSlot.startTime);
    }

    formatTime(isoStr) {
        const dt = new Date(isoStr);
        return dt.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    formatDateTime(isoStr) {
        const dt = new Date(isoStr);
        return dt.toLocaleString([], {
            weekday: 'long', month: 'long', day: 'numeric',
            hour: '2-digit', minute: '2-digit'
        });
    }

    extractError(err) {
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'An unexpected error occurred';
    }
}
