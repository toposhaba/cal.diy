import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import CONTACT_NAME_FIELD from '@salesforce/schema/Contact.Name';
import CONTACT_EMAIL_FIELD from '@salesforce/schema/Contact.Email';
import getActiveEventTypes from '@salesforce/apex/SchedulingController.getActiveEventTypes';
import getAvailableSlots from '@salesforce/apex/SchedulingController.getAvailableSlots';
import getEventTypeDurations from '@salesforce/apex/SchedulingController.getEventTypeDurations';
import createBooking from '@salesforce/apex/SchedulingController.createBooking';
import createBookingWithFields from '@salesforce/apex/SchedulingController.createBookingWithFields';
import createBookingWithCustomFields from '@salesforce/apex/SchedulingController.createBookingWithCustomFields';
import getBookingFieldsForEventType from '@salesforce/apex/SchedulingController.getBookingFieldsForEventType';
import createRecurringSeries from '@salesforce/apex/SchedulingController.createRecurringSeries';
import getPaymentCheckoutInfo from '@salesforce/apex/SchedulingController.getPaymentCheckoutInfo';
import completePayment from '@salesforce/apex/SchedulingController.completePayment';
import getBookingFormFields from '@salesforce/apex/SchedulingController.getBookingFormFields';
import getBookingLocationSettings from '@salesforce/apex/SchedulingController.getBookingLocationSettings';

export default class CalendarBooking extends LightningElement {
    @api hostUserId;
    @api compact = false;
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
    @track durationOptions = [];
    @track selectedDuration;
    @track customBookingFields = [];
    @track customFieldValues = {};
    @track paymentCheckoutInfo;
    @track bookerPhone = '';
    @track selectedContactId;
    @track locationType = 'in_person';
    @track locationAddress = '';
    @track googlePlacesApiKey;
    @track videoOptions = [];
    @track showLocationSection = false;

    @wire(getRecord, { recordId: '$selectedContactId', fields: [CONTACT_NAME_FIELD, CONTACT_EMAIL_FIELD] })
    wiredBookerContact({ error, data }) {
        if (!this.selectedContactId) {
            return;
        }
        if (data) {
            const name = data.fields.Name.value || '';
            const email = data.fields.Email.value || '';
            this.applyBookerContactDetails(name, email, this.selectedContactId);
        } else if (error) {
            this.error = this.extractError(error);
        }
    }

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

    get showShellHeader() {
        return !this.compact;
    }

    get shellClass() {
        return this.compact ? 'compact-shell' : 'full-shell';
    }

    get hasCustomBookingFields() {
        return this.customBookingFields && this.customBookingFields.length > 0;
    }

    get renderableCustomFields() {
        return this.customBookingFields.map(f => ({
            ...f,
            isSelect: f.fieldType === 'Select' || f.fieldType === 'RadioGroup',
            isMultiSelect: f.fieldType === 'MultiSelect',
            isCheckbox: f.fieldType === 'Checkbox',
            isTextArea: f.fieldType === 'TextArea',
            isPhone: f.fieldType === 'Phone',
            isEmail: f.fieldType === 'Email',
            isNumber: f.fieldType === 'Number',
            isText: f.fieldType === 'Text',
            selectOptions: (f.options || []).map(o => ({ label: o, value: o })),
            value: this.customFieldValues[f.id] || ''
        }));
    }

    get hasMultipleDurations() {
        return this.durationOptions && this.durationOptions.length > 1;
    }

    get isDurationStep() {
        return this.currentStep === 'duration-select';
    }

    get eventTypeDurationLabel() {
        if (!this.selectedEventType) {
            return '';
        }
        if (this.selectedDuration) {
            return `${this.selectedDuration} minutes`;
        }
        return `${this.selectedEventType.Duration_Minutes__c} minutes`;
    }

    get renderableFields() {
        return this.formFields
            .filter(f => f.apiName !== 'Location__c')
            .map(f => ({
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

    get locationTypeOptions() {
        const options = [{ label: 'In person', value: 'in_person' }];
        (this.videoOptions || []).forEach(option => {
            options.push({ label: option.label, value: option.value });
        });
        return options;
    }

    get isInPersonLocation() {
        return this.locationType === 'in_person';
    }

    get selectedVideoProvider() {
        return this.isInPersonLocation ? null : this.locationType;
    }

    get bookingLocation() {
        return this.isInPersonLocation ? this.locationAddress : null;
    }

    get hasMeetingLink() {
        return this.confirmedBooking
            && this.confirmedBooking.Location__c
            && this.confirmedBooking.Location__c.startsWith('http');
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
        const selectedId = event.detail.recordId || null;

        if (!selectedId) {
            this.selectedContactId = undefined;
            this.applyBookerContactDetails('', '', null);
            return;
        }

        this.selectedContactId = selectedId;
    }

    applyBookerContactDetails(name, email, contactId) {
        this.bookerName = name;
        this.bookerEmail = email;
        this.fieldValues = {
            ...this.fieldValues,
            Booker_Contact__c: contactId,
            Booker_Name__c: name,
            Booker_Email__c: email
        };
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
        this.selectedDuration = null;
        this.customBookingFields = [];
        this.customFieldValues = {};
        this.loadEventTypeConfig(eventTypeId);
    }

    async loadEventTypeConfig(eventTypeId) {
        this.isLoading = true;
        this.error = undefined;
        try {
            const [durations, customFields] = await Promise.all([
                getEventTypeDurations({ eventTypeId }),
                getBookingFieldsForEventType({ eventTypeId })
            ]);
            this.durationOptions = (durations || []).map(d => ({
                label: `${d} minutes`,
                value: d
            }));
            this.customBookingFields = customFields || [];
            if (this.durationOptions.length === 1) {
                this.selectedDuration = this.durationOptions[0].value;
                this.currentStep = 'date-select';
                this.loadSlotsForWeek();
            } else {
                this.currentStep = 'duration-select';
            }
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleDurationSelect(event) {
        this.selectedDuration = parseInt(event.detail.value, 10);
        this.currentStep = 'date-select';
        this.loadSlotsForWeek();
    }

    handleCustomFieldChange(event) {
        const fieldId = event.target.dataset.field;
        this.customFieldValues = { ...this.customFieldValues, [fieldId]: event.target.value };
    }

    handlePhoneChange(event) {
        this.bookerPhone = event.target.value;
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
                endDateStr: endDate,
                durationMinutes: this.selectedDuration
            });
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    async handleSlotSelect(event) {
        const slotIndex = parseInt(event.currentTarget.dataset.index, 10);
        this.selectedSlot = this.availableSlots[slotIndex];
        this.currentStep = 'booking-form';
        await this.loadLocationSettings();
    }

    async loadLocationSettings() {
        if (!this.selectedEventType) {
            return;
        }

        try {
            const settings = await getBookingLocationSettings({
                hostUserId: this.hostUserId || this.selectedEventType.Owner_User__c,
                eventTypeId: this.selectedEventType.Id
            });

            this.googlePlacesApiKey = settings.googlePlacesApiKey;
            this.videoOptions = settings.videoOptions || [];
            this.showLocationSection = true;
            this.locationAddress = settings.defaultLocation || this.selectedEventType.Location__c || '';

            if (settings.defaultVideoProvider) {
                this.locationType = settings.defaultVideoProvider;
            } else {
                this.locationType = 'in_person';
            }
        } catch (err) {
            this.showLocationSection = true;
            this.videoOptions = [];
            this.locationType = 'in_person';
            this.locationAddress = this.selectedEventType.Location__c || '';
        }
    }

    handleLocationTypeChange(event) {
        this.locationType = event.detail.value;
    }

    handleLocationChange(event) {
        this.locationAddress = event.detail.value;
        this.fieldValues = { ...this.fieldValues, Location__c: event.detail.value };
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
            if (this.hasCustomBookingFields) {
                this.confirmedBooking = await createBookingWithCustomFields({
                    eventTypeId: this.selectedEventType.Id,
                    startDateTimeStr: this.selectedSlot.startTime,
                    bookerEmail: this.bookerEmail,
                    bookerName: this.bookerName,
                    bookerPhone: this.bookerPhone,
                    customFieldResponses: this.customFieldValues,
                    location: this.bookingLocation,
                    videoProvider: this.selectedVideoProvider
                });
            } else if (this.hasFieldSet) {
                const values = { ...this.fieldValues };
                if (!values.Booker_Name__c) values.Booker_Name__c = this.bookerName;
                if (!values.Booker_Email__c) values.Booker_Email__c = this.bookerEmail;
                this.confirmedBooking = await createBookingWithFields({
                    eventTypeId: this.selectedEventType.Id,
                    startDateTimeStr: this.selectedSlot.startTime,
                    fieldValues: values,
                    location: this.bookingLocation,
                    videoProvider: this.selectedVideoProvider
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
                    attendeeEmails: [],
                    location: this.bookingLocation,
                    videoProvider: this.selectedVideoProvider
                });
            }
            this.bookingConfirmed = true;
            this.currentStep = 'confirmation';
            this.dispatchEvent(new CustomEvent('bookingcomplete', { bubbles: true, composed: true }));

            if (this.isPendingPayment && this.confirmedBooking) {
                this.paymentCheckoutInfo = await getPaymentCheckoutInfo({ bookingId: this.confirmedBooking.Id });
            } else if (this.successRedirectUrl) {
                window.location.assign(this.successRedirectUrl);
            }
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
            this.currentStep = this.hasMultipleDurations ? 'duration-select' : 'event-type';
            if (this.currentStep === 'event-type') {
                this.selectedEventType = null;
                this.availableSlots = [];
            }
        } else if (this.currentStep === 'duration-select') {
            this.currentStep = 'event-type';
            this.selectedEventType = null;
            this.durationOptions = [];
            this.selectedDuration = null;
        }
    }

    handleStartOver() {
        this.currentStep = 'event-type';
        this.selectedEventType = null;
        this.selectedDate = null;
        this.selectedSlot = null;
        this.bookerName = '';
        this.bookerEmail = '';
        this.bookerPhone = '';
        this.fieldValues = {};
        this.selectedContactId = undefined;
        this.customBookingFields = [];
        this.customFieldValues = {};
        this.durationOptions = [];
        this.selectedDuration = null;
        this.paymentCheckoutInfo = null;
        this.bookingConfirmed = false;
        this.confirmedBooking = null;
        this.isRecurring = false;
        this.recurringFrequency = 'Weekly';
        this.recurringOccurrences = 4;
        this.locationType = 'in_person';
        this.locationAddress = '';
        this.googlePlacesApiKey = null;
        this.videoOptions = [];
        this.showLocationSection = false;
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

    get isDurationSelectStep() {
        return this.currentStep === 'duration-select';
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

    get successRedirectUrl() {
        return this.selectedEventType && this.selectedEventType.Success_Redirect_URL__c
            ? this.selectedEventType.Success_Redirect_URL__c
            : null;
    }

    async handleCompletePayment() {
        this.isLoading = true;
        this.error = undefined;
        try {
            this.confirmedBooking = await completePayment({ bookingId: this.confirmedBooking.Id });
            if (this.successRedirectUrl) {
                window.location.assign(this.successRedirectUrl);
            }
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
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
