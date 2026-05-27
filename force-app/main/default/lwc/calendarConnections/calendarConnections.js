import { LightningElement, track, wire } from 'lwc';
import getConnections from '@salesforce/apex/CalendarConnectionController.getConnections';
import createConnection from '@salesforce/apex/CalendarConnectionController.createConnection';
import toggleConnection from '@salesforce/apex/CalendarConnectionController.toggleConnection';
import deleteConnection from '@salesforce/apex/CalendarConnectionController.deleteConnection';
import { refreshApex } from '@salesforce/apex';

export default class CalendarConnections extends LightningElement {
    @track connections = [];
    @track isLoading = false;
    @track error;
    @track showAddForm = false;

    newProvider = '';
    newCalendarId = '';
    newCheckConflicts = true;
    newPushEvents = false;

    wiredConnectionsResult;

    @wire(getConnections)
    wiredConnections(result) {
        this.wiredConnectionsResult = result;
        if (result.data) {
            this.connections = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = this.extractError(result.error);
        }
    }

    get providerOptions() {
        return [
            { label: 'Google Calendar', value: 'Google' },
            { label: 'Microsoft Outlook', value: 'Microsoft' },
            { label: 'Salesforce Events', value: 'Salesforce' }
        ];
    }

    get hasConnections() {
        return this.connections && this.connections.length > 0;
    }

    get noConnections() {
        return !this.hasConnections;
    }

    get notLoading() {
        return !this.isLoading;
    }

    get formattedConnections() {
        return this.connections.map(conn => ({
            ...conn,
            providerLabel: this.getProviderLabel(conn.Provider__c),
            statusLabel: conn.Is_Active__c ? 'Active' : 'Inactive',
            statusClass: conn.Is_Active__c ? 'slds-badge slds-theme_success' : 'slds-badge',
            toggleLabel: conn.Is_Active__c ? 'Disable' : 'Enable'
        }));
    }

    getProviderLabel(provider) {
        const map = { 'Google': 'Google Calendar', 'Microsoft': 'Microsoft Outlook', 'Salesforce': 'Salesforce Events' };
        return map[provider] || provider;
    }

    handleAddClick() {
        this.showAddForm = true;
    }

    handleProviderChange(event) {
        this.newProvider = event.detail.value;
    }

    handleCalendarIdChange(event) {
        this.newCalendarId = event.target.value;
    }

    handleCheckConflictsChange(event) {
        this.newCheckConflicts = event.target.checked;
    }

    handlePushEventsChange(event) {
        this.newPushEvents = event.target.checked;
    }

    async handleSaveConnection() {
        if (!this.newProvider) {
            this.error = 'Please select a provider';
            return;
        }

        this.isLoading = true;
        this.error = undefined;
        try {
            await createConnection({
                provider: this.newProvider,
                calendarId: this.newCalendarId,
                checkConflicts: this.newCheckConflicts,
                pushEvents: this.newPushEvents
            });
            this.showAddForm = false;
            this.resetForm();
            await refreshApex(this.wiredConnectionsResult);
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleCancelAdd() {
        this.showAddForm = false;
        this.resetForm();
    }

    async handleToggle(event) {
        const connectionId = event.currentTarget.dataset.id;
        this.isLoading = true;
        try {
            await toggleConnection({ connectionId });
            await refreshApex(this.wiredConnectionsResult);
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    async handleDelete(event) {
        const connectionId = event.currentTarget.dataset.id;
        this.isLoading = true;
        try {
            await deleteConnection({ connectionId });
            await refreshApex(this.wiredConnectionsResult);
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    resetForm() {
        this.newProvider = '';
        this.newCalendarId = '';
        this.newCheckConflicts = true;
        this.newPushEvents = false;
    }

    extractError(err) {
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'An unexpected error occurred';
    }
}
