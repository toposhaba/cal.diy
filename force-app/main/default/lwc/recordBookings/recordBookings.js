import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getBookingsForRecord from '@salesforce/apex/RecordBookingsController.getBookingsForRecord';

export default class RecordBookings extends NavigationMixin(LightningElement) {
    @api recordId;

    objectApiName;
    bookingsWire;
    bookings = [];
    contextType;
    emptyMessage;
    error;

    @wire(getRecord, { recordId: '$recordId' })
    wiredRecord({ error, data }) {
        if (data) {
            this.objectApiName = data.apiName;
        } else if (error) {
            this.error = this.extractError(error);
        }
    }

    @wire(getBookingsForRecord, { recordId: '$recordId', objectApiName: '$objectApiName' })
    wiredBookings(result) {
        this.bookingsWire = result;
        const { data, error } = result;

        if (data) {
            this.bookings = data.bookings || [];
            this.contextType = data.contextType;
            this.emptyMessage = data.emptyMessage;
            this.error = undefined;
        } else if (error) {
            this.bookings = [];
            this.error = this.extractError(error);
        }
    }

    get isLoading() {
        return !this.bookingsWire || (!this.bookingsWire.data && !this.bookingsWire.error);
    }

    get hasBookings() {
        return this.bookings.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.error && !this.hasBookings;
    }

    get cardTitle() {
        return 'Bookings';
    }

    get formattedBookings() {
        return this.bookings.map(booking => ({
            ...booking,
            whenDisplay: booking.formattedStart && booking.formattedEnd
                ? `${booking.formattedStart} - ${booking.formattedEnd}`
                : booking.formattedStart || '',
            bookerDisplay: booking.bookerName && booking.bookerEmail
                ? `${booking.bookerName} (${booking.bookerEmail})`
                : booking.bookerName || booking.bookerEmail || '',
            statusClass: this.getStatusClass(booking.status)
        }));
    }

    async handleRefresh() {
        if (this.bookingsWire) {
            await refreshApex(this.bookingsWire);
        }
    }

    handleViewBooking(event) {
        const bookingId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: bookingId,
                objectApiName: 'Booking__c',
                actionName: 'view'
            }
        });
    }

    getStatusClass(status) {
        const classes = {
            Accepted: 'slds-badge slds-theme_success',
            Pending: 'slds-badge slds-theme_warning',
            Cancelled: 'slds-badge slds-theme_error',
            Rejected: 'slds-badge slds-theme_error'
        };
        return classes[status] || 'slds-badge';
    }

    extractError(err) {
        if (err && err.body && err.body.message) {
            return err.body.message;
        }
        if (err && err.message) {
            return err.message;
        }
        return 'An unexpected error occurred';
    }
}
