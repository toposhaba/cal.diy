import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getOverview from '@salesforce/apex/IntegrationsAdminController.getOverview';
import getOrgCalendarAuthStatus from '@salesforce/apex/IntegrationsAdminController.getOrgCalendarAuthStatus';
import getNamedCredentialAuthUrl from '@salesforce/apex/CalendarConnectionController.getNamedCredentialAuthUrl';
import verifyConnection from '@salesforce/apex/CalendarConnectionController.verifyConnection';

const SECTIONS = [
    { value: 'overview', label: 'Overview', icon: 'utility:health' },
    { value: 'email', label: 'Email Deliverability', icon: 'utility:email' },
    { value: 'google', label: 'Google Calendar', icon: 'utility:date_input' },
    { value: 'microsoft', label: 'Microsoft Graph', icon: 'utility:date_input' },
    { value: 'zoom', label: 'Zoom (S2S)', icon: 'utility:video' },
    { value: 'payments', label: 'Stripe / Twilio', icon: 'utility:currency' },
    { value: 'hris', label: 'Workday / HRIS', icon: 'utility:company' },
    { value: 'permissions', label: 'Permission Sets & Hosts', icon: 'utility:people' }
];

export default class IntegrationsAdmin extends LightningElement {
    overview;
    error;
    isLoading = true;
    activeSection = 'overview';
    expandedPermSets = {};
    expandedUsers = {};
    orgCalendarAuth = {};
    wiredOverviewResult;

    @wire(getOverview)
    wiredOverview(result) {
        this.wiredOverviewResult = result;
        this.isLoading = true;
        if (result.data) {
            this.overview = this.decorateOverview(result.data);
            this.error = undefined;
            this.loadOrgCalendarAuthStatus();
        } else if (result.error) {
            this.overview = undefined;
            this.error = this.extractError(result.error);
        }
        this.isLoading = false;
    }

    async loadOrgCalendarAuthStatus() {
        try {
            const status = await getOrgCalendarAuthStatus();
            this.orgCalendarAuth = {
                Google: status.google?.authenticated === true,
                Microsoft: status.microsoft?.authenticated === true
            };
            if (this.overview) {
                this.overview = this.decorateOverview(this.wiredOverviewResult.data);
            }
        } catch (err) {
            this.orgCalendarAuth = { Google: false, Microsoft: false };
        }
    }

    decorateOverview(data) {
        const integrations = (data.integrations || []).map((item) => ({
            ...item,
            statusClass: this.statusClass(item.status),
            statusIcon: this.statusIcon(item.status),
            showMetadataLink: !!item.metadataSetupUrl,
            showAuthenticateButton: !!item.authenticateUrl && item.type === 'oauth',
            authStatusLabel: this.integrationAuthStatusLabel(item)
        }));

        const permissionSets = (data.permissionSets || []).map((ps) => {
            const isExpanded = !!this.expandedPermSets[ps.apiName];
            return {
                ...ps,
                expandKey: ps.apiName,
                isExpanded,
                toggleLabel: isExpanded ? 'Hide users' : 'Show users',
                existsLabel: ps.exists ? 'Deployed' : 'Not found in org',
                showUserList: ps.apiName === 'Scheduling_Host' || ps.apiName === 'Scheduling_Admin'
            };
        });

        const userSetups = (data.userSetups || []).map((user) => {
            const isExpanded = !!this.expandedUsers[user.userId];
            return {
                ...user,
                expandKey: user.userId,
                isExpanded,
                toggleLabel: isExpanded ? 'Hide details' : 'Show details',
                setupSummary: this.buildUserSetupSummary(user),
                permBadges: this.buildPermBadges(user),
                connectionSummary: this.buildConnectionSummary(user)
            };
        });

        const healthChecks = (data.healthChecks || []).map((hc) => ({
            ...hc,
            severityClass: this.severityClass(hc.severity),
            severityIcon: this.severityIcon(hc.severity),
            itemClass: `health-check-item health-check-item_severity-${hc.severity || 'info'}`,
            showSetupButton: !!hc.setupUrl,
            setupLabel: hc.setupLabel || 'Open Setup'
        }));

        const healthCheckSections = this.buildHealthCheckSections(healthChecks);

        const emailDeliverability = data.emailDeliverability
            ? {
                ...data.emailDeliverability,
                statusClass: this.statusClass(data.emailDeliverability.status),
                statusIcon: this.statusIcon(data.emailDeliverability.status),
                showSetupButton: !!data.emailDeliverability.setupUrl,
                showDeliverabilityButton: !!data.emailDeliverability.deliverabilitySetupUrl,
                verifiedCountLabel: (data.emailDeliverability.verifiedCount || 0) + ' verified',
                unverifiedCountLabel: (data.emailDeliverability.unverifiedCount || 0) + ' unverified',
                hasVerifiedAddresses: (data.emailDeliverability.verifiedAddresses || []).length > 0
            }
            : null;

        return {
            ...data,
            integrations,
            permissionSets,
            userSetups,
            healthChecks,
            healthCheckSections,
            emailDeliverability,
            calendarSyncLabel: data.calendarSyncJobScheduled ? 'Scheduled' : 'Not scheduled',
            calendarSyncClass: data.calendarSyncJobScheduled ? 'slds-theme_success' : 'slds-theme_warning',
            showCalendarSyncSetup: !!data.calendarSyncSetupUrl,
            calendarSyncGuidance: data.calendarSyncGuidance,
            hrWorkforceSyncLabel: data.hrWorkforceSyncJobScheduled ? 'Scheduled' : 'Not scheduled',
            hrWorkforceSyncClass: data.hrWorkforceSyncJobScheduled ? 'slds-theme_success' : 'slds-theme_warning',
            hrWorkforceSyncLastSyncLabel: data.hrWorkforceSyncLastSync
                ? 'Last sync: ' + data.hrWorkforceSyncLastSync
                : 'No successful sync yet',
            showHrWorkforceSyncSetup: !!data.hrWorkforceSyncSetupUrl
        };
    }

    integrationAuthStatusLabel(item) {
        if (item.key === 'Google' || item.key === 'Microsoft') {
            const authenticated = this.orgCalendarAuth[item.key];
            if (authenticated === true) {
                return 'Named Principal authenticated';
            }
            if (authenticated === false) {
                return 'Named Principal not authenticated';
            }
            return 'Checking authentication...';
        }
        if (item.key === 'Zoom') {
            return item.statusLabel;
        }
        return null;
    }

    buildHealthCheckSections(healthChecks) {
        const sectionOrder = ['Configuration', 'Email Deliverability', 'Calendar Sync', 'HR Workforce Sync', 'Payments', 'Overall'];
        const byCategory = new Map();

        healthChecks.forEach((check) => {
            const category = check.category || 'Other';
            if (!byCategory.has(category)) {
                byCategory.set(category, []);
            }
            byCategory.get(category).push(check);
        });

        const sections = [];
        sectionOrder.forEach((category) => {
            if (byCategory.has(category)) {
                sections.push({ category, checks: byCategory.get(category) });
                byCategory.delete(category);
            }
        });
        byCategory.forEach((checks, category) => {
            sections.push({ category, checks });
        });
        return sections;
    }

    buildUserSetupSummary(user) {
        const parts = [];
        parts.push(`${user.scheduleCount || 0} schedule(s)`);
        parts.push(`${user.activeEventTypeCount || 0} active event type(s)`);
        if (!user.hasCalendarConnection) {
            parts.push('no calendar connections');
        }
        return parts.join(' · ');
    }

    buildPermBadges(user) {
        const badges = [];
        if (user.hasAdminPermission) {
            badges.push({ label: 'Admin', className: 'slds-badge slds-theme_inverse' });
        }
        if (user.hasHostPermission) {
            badges.push({ label: 'Host', className: 'slds-badge' });
        }
        return badges;
    }

    buildConnectionSummary(user) {
        if (!user.connections || user.connections.length === 0) {
            return 'None';
        }
        return user.connections
            .map((c) => {
                const sync = c.lastSync ? 'synced' : 'never synced';
                const active = c.isActive ? 'active' : 'inactive';
                return `${c.provider} (${active}, ${sync})`;
            })
            .join('; ');
    }

    findIntegration(key) {
        return (this.overview?.integrations || []).find((i) => i.key === key);
    }

    filterIntegrations(keys) {
        const keySet = new Set(keys);
        return (this.overview?.integrations || []).filter((i) => keySet.has(i.key));
    }

    get navSections() {
        return SECTIONS.map((section) => ({
            ...section,
            navClass: section.value === this.activeSection ? 'nav-item nav-item_active' : 'nav-item',
            ariaCurrent: section.value === this.activeSection ? 'page' : null
        }));
    }

    get currentSectionIndex() {
        return SECTIONS.findIndex((s) => s.value === this.activeSection);
    }

    get currentSectionLabel() {
        const section = SECTIONS.find((s) => s.value === this.activeSection);
        return section ? section.label : '';
    }

    get showPrevButton() {
        return this.currentSectionIndex > 0;
    }

    get showNextButton() {
        return this.currentSectionIndex < SECTIONS.length - 1;
    }

    get isOverviewSection() {
        return this.activeSection === 'overview';
    }

    get isEmailSection() {
        return this.activeSection === 'email';
    }

    get isGoogleSection() {
        return this.activeSection === 'google';
    }

    get isMicrosoftSection() {
        return this.activeSection === 'microsoft';
    }

    get isZoomSection() {
        return this.activeSection === 'zoom';
    }

    get isPaymentsSection() {
        return this.activeSection === 'payments';
    }

    get isHrisSection() {
        return this.activeSection === 'hris';
    }

    get isPermissionsSection() {
        return this.activeSection === 'permissions';
    }

    get googleIntegration() {
        return this.findIntegration('Google');
    }

    get microsoftIntegration() {
        return this.findIntegration('Microsoft');
    }

    get zoomIntegration() {
        return this.findIntegration('Zoom');
    }

    get paymentIntegrations() {
        return this.filterIntegrations(['Stripe', 'Twilio', 'GoogleMaps']);
    }

    get hrisIntegrations() {
        return (this.overview?.integrations || []).filter(
            (i) => i.key !== 'Google' && i.key !== 'Microsoft' && i.key !== 'Zoom'
                && i.key !== 'Stripe' && i.key !== 'Twilio' && i.key !== 'GoogleMaps'
        );
    }

    statusClass(status) {
        if (status === 'configured') return 'slds-theme_success';
        if (status === 'partial') return 'slds-theme_warning';
        if (status === 'not_configured') return 'slds-theme_error';
        if (status === 'coming_soon') return 'slds-theme_info';
        return 'slds-theme_info';
    }

    statusIcon(status) {
        if (status === 'configured') return 'utility:success';
        if (status === 'partial') return 'utility:warning';
        if (status === 'not_configured') return 'utility:error';
        if (status === 'coming_soon') return 'utility:clock';
        return 'utility:info';
    }

    severityClass(severity) {
        if (severity === 'error') return 'slds-alert_error';
        if (severity === 'warning') return 'slds-alert_warning';
        if (severity === 'success') return 'slds-alert_success';
        return 'slds-alert_info';
    }

    severityIcon(severity) {
        if (severity === 'error') return 'utility:error';
        if (severity === 'warning') return 'utility:warning';
        if (severity === 'success') return 'utility:success';
        return 'utility:info';
    }

    get hasOverview() {
        return !!this.overview;
    }

    get hostUserCount() {
        return this.overview?.userSetups?.length || 0;
    }

    handleSectionSelect(event) {
        this.activeSection = event.currentTarget.dataset.section;
        this.error = undefined;
    }

    handlePrevSection() {
        if (this.currentSectionIndex > 0) {
            this.activeSection = SECTIONS[this.currentSectionIndex - 1].value;
            this.error = undefined;
        }
    }

    handleNextSection() {
        if (this.currentSectionIndex < SECTIONS.length - 1) {
            this.activeSection = SECTIONS[this.currentSectionIndex + 1].value;
            this.error = undefined;
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        await refreshApex(this.wiredOverviewResult);
        await this.loadOrgCalendarAuthStatus();
        this.isLoading = false;
    }

    handleTogglePermSet(event) {
        const key = event.currentTarget.dataset.key;
        this.expandedPermSets = {
            ...this.expandedPermSets,
            [key]: !this.expandedPermSets[key]
        };
        if (this.overview) {
            this.overview = this.decorateOverview(this.wiredOverviewResult.data);
        }
    }

    handleToggleUser(event) {
        const key = event.currentTarget.dataset.key;
        this.expandedUsers = {
            ...this.expandedUsers,
            [key]: !this.expandedUsers[key]
        };
        if (this.overview) {
            this.overview = this.decorateOverview(this.wiredOverviewResult.data);
        }
    }

    handleOpenSetup(event) {
        const url = event.currentTarget.dataset.url;
        if (url) {
            window.open(url, '_blank');
        }
    }

    async handleAuthenticateIntegration(event) {
        const provider = event.currentTarget.dataset.provider;
        if (!provider) {
            const url = event.currentTarget.dataset.url;
            if (url) {
                window.open(url, '_blank');
            }
            return;
        }

        this.isLoading = true;
        this.error = undefined;
        try {
            const authInfo = await getNamedCredentialAuthUrl({
                provider,
                returnPageApiName: 'Integrations'
            });
            if (authInfo.type === 'oauth_not_configured') {
                this.error = authInfo.message;
                if (authInfo.setupUrl) {
                    window.open(authInfo.setupUrl, '_blank');
                }
                return;
            }
            if (authInfo.authUrl) {
                const popup = window.open(
                    authInfo.authUrl,
                    'calDiyOAuth',
                    'width=600,height=700,menubar=no,toolbar=no,location=yes,status=yes,resizable=yes,scrollbars=yes'
                );
                if (!popup || popup.closed || typeof popup.closed === 'undefined') {
                    this.error = 'Popup blocked. Allow popups for this site, then try again.';
                    return;
                }
                popup.focus();
            } else if (authInfo.setupUrl) {
                window.open(authInfo.setupUrl, '_blank');
            }
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    async handleVerifyOrgAuth(event) {
        const provider = event.currentTarget.dataset.provider;
        if (!provider) {
            return;
        }
        this.isLoading = true;
        this.error = undefined;
        try {
            const result = await verifyConnection({ provider });
            await this.loadOrgCalendarAuthStatus();
            if (!result.authenticated) {
                this.error = result.message;
            }
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    extractError(err) {
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'An unexpected error occurred';
    }
}
