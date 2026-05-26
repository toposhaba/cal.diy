import { LightningElement, track } from 'lwc';
import getMyBookings from '@salesforce/apex/SchedulingController.getMyBookings';
import cancelBooking from '@salesforce/apex/SchedulingController.cancelBooking';
import confirmBooking from '@salesforce/apex/SchedulingController.confirmBooking';

export default class BookingManager extends LightningElement {
    @track bookings = [];
    @track isLoading = false;
    @track error;
    @track startDate;
    @track endDate;
    @track selectedBookingId;
    @track showCancelModal = false;
    @track cancelReason = '';

    connectedCallback() {
        const today = new Date();
        this.startDate = today.toISOString().split('T')[0];
        const nextMonth = new Date(today);
        nextMonth.setDate(nextMonth.getDate() + 30);
        this.endDate = nextMonth.toISOString().split('T')[0];
        this.loadBookings();
    }

    async loadBookings() {
        this.isLoading = true;
        this.error = undefined;
        try {
            this.bookings = await getMyBookings({
                startDateStr: this.startDate,
                endDateStr: this.endDate
            });
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
        this.loadBookings();
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
        this.loadBookings();
    }

    handleConfirm(event) {
        const bookingId = event.currentTarget.dataset.id;
        this.doConfirm(bookingId);
    }

    async doConfirm(bookingId) {
        this.isLoading = true;
        try {
            await confirmBooking({ bookingId });
            await this.loadBookings();
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleCancelClick(event) {
        this.selectedBookingId = event.currentTarget.dataset.id;
        this.showCancelModal = true;
    }

    handleCancelReasonChange(event) {
        this.cancelReason = event.target.value;
    }

    handleCancelConfirm() {
        this.doCancelBooking();
    }

    handleCancelModalClose() {
        this.showCancelModal = false;
        this.cancelReason = '';
        this.selectedBookingId = null;
    }

    async doCancelBooking() {
        this.isLoading = true;
        try {
            await cancelBooking({
                bookingId: this.selectedBookingId,
                reason: this.cancelReason
            });
            this.showCancelModal = false;
            this.cancelReason = '';
            this.selectedBookingId = null;
            await this.loadBookings();
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    get hasBookings() {
        return this.bookings && this.bookings.length > 0;
    }

    get formattedBookings() {
        return this.bookings.map(b => ({
            ...b,
            formattedStart: this.formatDateTime(b.Start_DateTime__c),
            formattedEnd: this.formatTime(b.End_DateTime__c),
            isPending: b.Status__c === 'Pending',
            isActive: b.Status__c === 'Accepted' || b.Status__c === 'Pending',
            statusClass: this.getStatusClass(b.Status__c)
        }));
    }

    getStatusClass(status) {
        const classes = {
            'Accepted': 'slds-badge slds-theme_success',
            'Pending': 'slds-badge slds-theme_warning',
            'Cancelled': 'slds-badge slds-theme_error',
            'Rejected': 'slds-badge slds-theme_error'
        };
        return classes[status] || 'slds-badge';
    }

    formatDateTime(isoStr) {
        if (!isoStr) return '';
        const dt = new Date(isoStr);
        return dt.toLocaleString([], {
            weekday: 'short', month: 'short', day: 'numeric',
            hour: '2-digit', minute: '2-digit'
        });
    }

    formatTime(isoStr) {
        if (!isoStr) return '';
        const dt = new Date(isoStr);
        return dt.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    extractError(err) {
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'An unexpected error occurred';
    }
}
