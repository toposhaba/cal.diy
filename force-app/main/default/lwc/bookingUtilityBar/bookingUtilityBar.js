import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getMyBookings from '@salesforce/apex/SchedulingController.getMyBookings';
import cancelBooking from '@salesforce/apex/SchedulingController.cancelBooking';
import confirmBooking from '@salesforce/apex/SchedulingController.confirmBooking';

export default class BookingUtilityBar extends NavigationMixin(LightningElement) {
    @track bookings = [];
    @track isLoading = false;
    @track error;
    @track activeView = 'upcoming';

    connectedCallback() {
        this.loadBookings();
    }

    get isNewBookingView() { return this.activeView === 'new-booking'; }
    get isListView() { return !this.isNewBookingView; }
    get isUpcomingView() { return this.activeView === 'upcoming'; }
    get isPendingView() { return this.activeView === 'pending'; }
    get upcomingVariant() { return this.activeView === 'upcoming' ? 'brand' : 'neutral'; }
    get pendingVariant() { return this.activeView === 'pending' ? 'brand' : 'neutral'; }

    get upcomingBookings() {
        return this.bookings.filter(b => b.Status__c === 'Accepted');
    }

    get pendingBookings() {
        return this.bookings.filter(b => b.Status__c === 'Pending');
    }

    get hasUpcoming() { return this.upcomingBookings.length > 0; }
    get hasPending() { return this.pendingBookings.length > 0; }
    get pendingCount() { return this.pendingBookings.length; }
    get upcomingCount() { return this.upcomingBookings.length; }

    get displayedBookings() {
        const list = this.activeView === 'pending' ? this.pendingBookings : this.upcomingBookings;
        return list.slice(0, 10).map(b => ({
            ...b,
            formattedTime: this.formatBookingTime(b.Start_DateTime__c),
            eventName: b.Event_Type__r ? b.Event_Type__r.Name : 'Meeting',
            isPending: b.Status__c === 'Pending'
        }));
    }

    get hasDisplayedBookings() { return this.displayedBookings.length > 0; }
    get emptyMessage() {
        return this.activeView === 'pending'
            ? 'No pending bookings awaiting approval.'
            : 'No upcoming bookings scheduled.';
    }

    async loadBookings() {
        this.isLoading = true;
        this.error = undefined;
        try {
            const today = new Date().toISOString().split('T')[0];
            const futureDate = new Date();
            futureDate.setDate(futureDate.getDate() + 30);
            const endDate = futureDate.toISOString().split('T')[0];
            this.bookings = await getMyBookings({ startDateStr: today, endDateStr: endDate });
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleViewChange(event) {
        this.activeView = event.target.dataset.view;
    }

    async handleConfirm(event) {
        const bookingId = event.target.dataset.id;
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

    async handleCancel(event) {
        const bookingId = event.target.dataset.id;
        this.isLoading = true;
        try {
            await cancelBooking({ bookingId, reason: 'Cancelled from utility bar' });
            await this.loadBookings();
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleRefresh() {
        this.loadBookings();
    }

    handleNewBooking() {
        this.error = undefined;
        this.activeView = 'new-booking';
    }

    handleBackFromNewBooking() {
        this.activeView = 'upcoming';
    }

    handleBookingComplete() {
        this.loadBookings();
    }

    handleViewAll() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Booking_Manager'
            }
        });
    }

    handleOpenBooking(event) {
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

    formatBookingTime(isoStr) {
        if (!isoStr) return '';
        const dt = new Date(isoStr);
        const now = new Date();
        const tomorrow = new Date(now);
        tomorrow.setDate(tomorrow.getDate() + 1);

        let dayLabel;
        if (dt.toDateString() === now.toDateString()) {
            dayLabel = 'Today';
        } else if (dt.toDateString() === tomorrow.toDateString()) {
            dayLabel = 'Tomorrow';
        } else {
            dayLabel = dt.toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' });
        }
        const time = dt.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        return `${dayLabel} at ${time}`;
    }

    extractError(err) {
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'An unexpected error occurred';
    }
}
