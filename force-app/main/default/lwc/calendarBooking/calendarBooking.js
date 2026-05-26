import { LightningElement, api, track } from 'lwc';
import getActiveEventTypes from '@salesforce/apex/SchedulingController.getActiveEventTypes';
import getAvailableSlots from '@salesforce/apex/SchedulingController.getAvailableSlots';
import createBooking from '@salesforce/apex/SchedulingController.createBooking';

export default class CalendarBooking extends LightningElement {
    @api hostUserId;
    @track eventTypes = [];
    @track availableSlots = [];
    @track selectedEventType;
    @track selectedDate;
    @track selectedSlot;
    @track bookerName = '';
    @track bookerEmail = '';
    @track isLoading = false;
    @track error;
    @track bookingConfirmed = false;
    @track confirmedBooking;
    @track currentStep = 'event-type';

    connectedCallback() {
        this.loadEventTypes();
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

    async handleBookingSubmit() {
        if (!this.validateForm()) return;

        this.isLoading = true;
        this.error = undefined;
        try {
            this.confirmedBooking = await createBooking({
                eventTypeId: this.selectedEventType.Id,
                startDateTimeStr: this.selectedSlot.startTime,
                bookerEmail: this.bookerEmail,
                bookerName: this.bookerName,
                attendeeEmails: []
            });
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

    get hasSlots() {
        return this.availableSlots && this.availableSlots.length > 0;
    }

    get formattedSlots() {
        return this.availableSlots.map((slot, index) => ({
            ...slot,
            index,
            formattedTime: this.formatTime(slot.startTime)
        }));
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
