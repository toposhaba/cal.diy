import { LightningElement, api, track } from 'lwc';
import getActiveRoutingForms from '@salesforce/apex/SchedulingController.getActiveRoutingForms';
import getRoutingFormFields from '@salesforce/apex/SchedulingController.getRoutingFormFields';
import evaluateRoutingForm from '@salesforce/apex/SchedulingController.evaluateRoutingForm';
import getAvailableSlots from '@salesforce/apex/SchedulingController.getAvailableSlots';
import createBooking from '@salesforce/apex/SchedulingController.createBooking';

export default class RoutingForm extends LightningElement {
    @api routingFormId;
    @api hostUserId;
    @track forms = [];
    @track fields = [];
    @track fieldValues = {};
    @track selectedForm;
    @track resolvedEventType;
    @track availableSlots = [];
    @track selectedDate;
    @track selectedSlot;
    @track bookerName = '';
    @track bookerEmail = '';
    @track isLoading = false;
    @track error;
    @track bookingConfirmed = false;
    @track confirmedBooking;
    @track currentStep = 'form-select';

    connectedCallback() {
        if (this.routingFormId) {
            this.selectedForm = { Id: this.routingFormId };
            this.currentStep = 'questions';
            this.loadFields();
        } else {
            this.loadForms();
        }
    }

    async loadForms() {
        this.isLoading = true;
        try {
            this.forms = await getActiveRoutingForms({ hostUserId: this.hostUserId || null });
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    async loadFields() {
        this.isLoading = true;
        this.error = undefined;
        try {
            this.fields = await getRoutingFormFields({ routingFormId: this.selectedForm.Id });
            this.fieldValues = {};
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleFormSelect(event) {
        this.selectedForm = this.forms.find(f => f.Id === event.currentTarget.dataset.id);
        this.currentStep = 'questions';
        this.loadFields();
    }

    handleFieldChange(event) {
        const fieldId = event.target.dataset.field;
        this.fieldValues = { ...this.fieldValues, [fieldId]: event.target.value };
    }

    async handleEvaluateRoute() {
        if (!this.validateQuestions()) return;

        this.isLoading = true;
        this.error = undefined;
        try {
            this.resolvedEventType = await evaluateRoutingForm({
                routingFormId: this.selectedForm.Id,
                fieldResponses: this.fieldValues
            });
            this.currentStep = 'date-select';
            const today = new Date();
            this.selectedDate = today.toISOString().split('T')[0];
            await this.loadSlotsForDate();
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleDateChange(event) {
        this.selectedDate = event.target.value;
        this.selectedSlot = null;
        this.loadSlotsForDate();
    }

    async loadSlotsForDate() {
        if (!this.resolvedEventType || !this.selectedDate) return;

        this.isLoading = true;
        try {
            this.availableSlots = await getAvailableSlots({
                eventTypeId: this.resolvedEventType.eventTypeId,
                startDateStr: this.selectedDate,
                endDateStr: this.selectedDate,
                durationMinutes: null
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
        if (!this.validateBookingForm()) return;

        this.isLoading = true;
        this.error = undefined;
        try {
            this.confirmedBooking = await createBooking({
                eventTypeId: this.resolvedEventType.eventTypeId,
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

    handleStartOver() {
        this.currentStep = this.routingFormId ? 'questions' : 'form-select';
        this.selectedForm = this.routingFormId ? { Id: this.routingFormId } : null;
        this.fields = [];
        this.fieldValues = {};
        this.resolvedEventType = null;
        this.availableSlots = [];
        this.selectedSlot = null;
        this.bookerName = '';
        this.bookerEmail = '';
        this.bookingConfirmed = false;
        this.confirmedBooking = null;
        this.error = undefined;
        if (this.routingFormId) {
            this.loadFields();
        } else {
            this.loadForms();
        }
    }

    validateQuestions() {
        const inputs = this.template.querySelectorAll('[data-field]');
        let isValid = true;
        inputs.forEach(input => {
            if (!input.checkValidity()) {
                input.reportValidity();
                isValid = false;
            }
        });
        return isValid;
    }

    validateBookingForm() {
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

    get isFormSelectStep() { return this.currentStep === 'form-select'; }
    get isQuestionsStep() { return this.currentStep === 'questions'; }
    get isDateSelectStep() { return this.currentStep === 'date-select'; }
    get isBookingFormStep() { return this.currentStep === 'booking-form'; }
    get isConfirmationStep() { return this.currentStep === 'confirmation'; }
    get hasForms() { return this.forms && this.forms.length > 0; }
    get hasFields() { return this.fields && this.fields.length > 0; }
    get hasSlots() { return this.availableSlots && this.availableSlots.length > 0; }
    get notLoading() { return !this.isLoading; }

    get renderableFields() {
        return this.fields.map(f => ({
            ...f,
            isSelect: f.fieldType === 'Select',
            isEmail: f.fieldType === 'Email',
            isPhone: f.fieldType === 'Phone',
            isText: f.fieldType === 'Text' || f.fieldType === 'MultiSelect',
            value: this.fieldValues[f.id] || '',
            selectOptions: (f.options || []).map(o => ({ label: o, value: o }))
        }));
    }

    get formattedSlots() {
        return this.availableSlots.map((slot, index) => {
            const formattedTime = this.formatTime(slot.startTime);
            const slotLabel = slot.availableSeats > 1
                ? `${formattedTime} (${slot.availableSeats} seats)`
                : formattedTime;
            return { ...slot, index, formattedTime, slotLabel };
        });
    }

    get selectedSlotFormatted() {
        if (!this.selectedSlot) return '';
        return this.formatDateTime(this.selectedSlot.startTime);
    }

    get minDate() {
        return new Date().toISOString().split('T')[0];
    }

    formatTime(isoStr) {
        return new Date(isoStr).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    formatDateTime(isoStr) {
        return new Date(isoStr).toLocaleString([], {
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
