import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getConnections from '@salesforce/apex/CalendarConnectionController.getConnections';
import createConnection from '@salesforce/apex/CalendarConnectionController.createConnection';
import verifyConnection from '@salesforce/apex/CalendarConnectionController.verifyConnection';
import toggleConnection from '@salesforce/apex/CalendarConnectionController.toggleConnection';
import deleteConnection from '@salesforce/apex/CalendarConnectionController.deleteConnection';
import { refreshApex } from '@salesforce/apex';

export default class CalendarConnections extends NavigationMixin(LightningElement) {
    @track connections = [];
    @track isLoading = false;
    @track error;
    @track showAddForm = false;
    @track orgAuthByProvider = {};
    @track orgAuthLoaded = false;

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
            this.loadOrgAuthStatus();
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

    get orgAuthNotice() {
        const googleReady = this.orgAuthByProvider.Google === true;
        const microsoftReady = this.orgAuthByProvider.Microsoft === true;
        if (googleReady && microsoftReady) {
            return null;
        }
        const missing = [];
        if (this.orgAuthByProvider.Google === false) {
            missing.push('Google Calendar');
        }
        if (this.orgAuthByProvider.Microsoft === false) {
            missing.push('Microsoft Outlook');
        }
        if (missing.length === 0) {
            return null;
        }
        return `Org-level authentication is required for ${missing.join(' and ')}. Ask your Scheduling Admin to authenticate in Integrations.`;
    }

    get formattedConnections() {
        return this.connections.map(conn => {
            const usesOrgAuth = conn.Provider__c === 'Google' || conn.Provider__c === 'Microsoft';
            const orgReady = usesOrgAuth ? this.orgAuthByProvider[conn.Provider__c] === true : true;
            return {
                ...conn,
                providerLabel: this.getProviderLabel(conn.Provider__c),
                statusLabel: conn.Is_Active__c ? 'Active' : 'Inactive',
                statusClass: conn.Is_Active__c ? 'slds-badge slds-theme_success' : 'slds-badge',
                toggleLabel: conn.Is_Active__c ? 'Disable' : 'Enable',
                integrationLabel: usesOrgAuth
                    ? (orgReady ? 'Org integration ready' : 'Awaiting admin authentication')
                    : 'Salesforce Events',
                integrationClass: usesOrgAuth
                    ? (orgReady ? 'slds-badge slds-theme_success slds-m-left_xx-small' : 'slds-badge slds-m-left_xx-small')
                    : 'slds-badge slds-m-left_xx-small'
            };
        });
    }

    getProviderLabel(provider) {
        const map = { Google: 'Google Calendar', Microsoft: 'Microsoft Outlook', Salesforce: 'Salesforce Events' };
        return map[provider] || provider;
    }

    async loadOrgAuthStatus() {
        try {
            const [googleResult, microsoftResult] = await Promise.all([
                verifyConnection({ provider: 'Google' }),
                verifyConnection({ provider: 'Microsoft' })
            ]);
            this.orgAuthByProvider = {
                Google: googleResult.authenticated === true,
                Microsoft: microsoftResult.authenticated === true
            };
        } catch (err) {
            this.orgAuthByProvider = { Google: false, Microsoft: false };
        } finally {
            this.orgAuthLoaded = true;
        }
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
            if (this.newProvider === 'Google' || this.newProvider === 'Microsoft') {
                const verifyResult = await verifyConnection({ provider: this.newProvider });
                if (!verifyResult.authenticated) {
                    this.error = verifyResult.message ||
                        'Org calendar integration is not authenticated. Ask your Scheduling Admin to configure it in Integrations.';
                    return;
                }
            }

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

    handleOpenIntegrations() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'Integrations' }
        });
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
