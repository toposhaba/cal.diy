public with sharing class EmailDeliverabilityService {

    @TestVisible
    private static List<OrgWideEmailAddress> orgWideEmailsOverride;
    @TestVisible
    private static Boolean isSandboxOverride;

    public static EmailDeliverabilitySummary buildSummary(String orgUrl) {
        EmailDeliverabilitySummary summary = new EmailDeliverabilitySummary();
        summary.setupUrl = orgUrl + '/lightning/setup/OrgWideEmailAddresses/home';
        summary.deliverabilitySetupUrl = orgUrl + '/lightning/setup/Deliverability/home';
        summary.verifiedAddresses = new List<String>();
        summary.checklistItems = buildChecklist();
        summary.verifiedCount = 0;
        summary.unverifiedCount = 0;

        for (OrgWideEmailAddress owe : queryOrgWideEmails()) {
            if (owe.IsVerified) {
                summary.verifiedCount++;
                summary.verifiedAddresses.add(owe.Address);
            } else {
                summary.unverifiedCount++;
            }
        }

        summary.isSandbox = resolveIsSandbox();
        summary.substituteSenderOnly = summary.verifiedCount == 0;
        summary.senderDisplayName = 'Cal.DIY Scheduling';

        if (summary.verifiedCount > 0) {
            summary.status = 'configured';
            summary.statusLabel = 'Org-wide email verified';
            summary.detail =
                summary.verifiedCount + ' verified org-wide address(es). Booking emails send from org-wide email with the ' +
                summary.senderDisplayName + ' display name.';
            summary.guidance =
                'For production, use a custom domain address (e.g. scheduling@yourdomain.com), verify the domain in Salesforce, ' +
                'and configure SPF, DKIM, and DMARC in DNS.';
        } else if (summary.unverifiedCount > 0) {
            summary.status = 'partial';
            summary.statusLabel = 'Verification pending';
            summary.detail =
                summary.unverifiedCount + ' org-wide address(es) exist but none are verified. Complete domain verification in Setup.';
            summary.guidance =
                'Verify your domain in Setup, then confirm the org-wide address. Until verified, emails may use the Salesforce substitute sender.';
        } else if (summary.isSandbox) {
            summary.status = 'not_configured';
            summary.statusLabel = 'Substitute sender (sandbox)';
            summary.detail =
                'No verified org-wide email. Booking emails use the Salesforce substitute sender (*.sfcustomeremail.com). ' +
                'Gmail may warn that the sender is impersonating a host user.';
            summary.guidance =
                'Scratch and sandbox orgs can use substitute sender for testing. For production, add an org-wide email on your domain, ' +
                'verify SPF/DKIM/DMARC, and set Deliverability access level to All Email.';
        } else {
            summary.status = 'not_configured';
            summary.statusLabel = 'No org-wide email';
            summary.detail =
                'No org-wide email address is configured. Booking emails rely on substitute sender and may trigger Gmail impersonation warnings.';
            summary.guidance =
                'Add an Organization-Wide Email Address on your verified domain. Cal.DIY sets the From display name to ' +
                summary.senderDisplayName + ' to avoid matching a host user name.';
        }

        return summary;
    }

    public static List<IntegrationsAdminController.HealthCheck> buildHealthChecks(String orgUrl) {
        List<IntegrationsAdminController.HealthCheck> checks = new List<IntegrationsAdminController.HealthCheck>();
        EmailDeliverabilitySummary summary = buildSummary(orgUrl);

        if (summary.verifiedCount == 0) {
            IntegrationsAdminController.HealthCheck hc = new IntegrationsAdminController.HealthCheck();
            hc.severity = summary.isSandbox ? 'warning' : 'error';
            hc.category = 'Email Deliverability';
            hc.title = summary.isSandbox
                ? 'Using Salesforce substitute sender'
                : 'No verified org-wide email address';
            hc.detail = summary.detail;
            hc.setupUrl = summary.setupUrl;
            hc.setupLabel = 'Org-Wide Email Addresses';
            checks.add(hc);
        } else if (summary.unverifiedCount > 0) {
            IntegrationsAdminController.HealthCheck hc = new IntegrationsAdminController.HealthCheck();
            hc.severity = 'warning';
            hc.category = 'Email Deliverability';
            hc.title = 'Unverified org-wide email addresses';
            hc.detail = summary.unverifiedCount + ' org-wide address(es) are awaiting domain verification.';
            hc.setupUrl = summary.setupUrl;
            hc.setupLabel = 'Verify Addresses';
            checks.add(hc);
        }

        IntegrationsAdminController.HealthCheck deliverabilityHc = new IntegrationsAdminController.HealthCheck();
        deliverabilityHc.severity = 'info';
        deliverabilityHc.category = 'Email Deliverability';
        deliverabilityHc.title = 'Confirm Deliverability access level';
        deliverabilityHc.detail =
            'In Setup → Deliverability, ensure access level is All Email for production. ' +
            'This setting cannot be queried from Apex; verify manually after deployment.';
        deliverabilityHc.setupUrl = summary.deliverabilitySetupUrl;
        deliverabilityHc.setupLabel = 'Open Deliverability';
        checks.add(deliverabilityHc);

        return checks;
    }

    private static List<OrgWideEmailAddress> queryOrgWideEmails() {
        if (Test.isRunningTest() && orgWideEmailsOverride != null) {
            return orgWideEmailsOverride;
        }
        return [
            SELECT Id, Address, DisplayName, IsVerified
            FROM OrgWideEmailAddress
            ORDER BY CreatedDate ASC
        ];
    }

    private static Boolean resolveIsSandbox() {
        if (Test.isRunningTest() && isSandboxOverride != null) {
            return isSandboxOverride;
        }
        Organization org = [SELECT IsSandbox FROM Organization LIMIT 1];
        return org.IsSandbox;
    }

    @TestVisible
    private static void resetTestOverrides() {
        orgWideEmailsOverride = null;
        isSandboxOverride = null;
    }

    public static List<String> buildChecklist() {
        return new List<String>{
            'Add an Organization-Wide Email Address (Setup → Organization-Wide Email Addresses)',
            'Verify the sending domain in Salesforce',
            'Configure SPF, DKIM, and DMARC DNS records for your custom domain',
            'Set Deliverability access level to All Email (Setup → Deliverability)',
            'Confirm booking confirmation emails show From as Cal.DIY Scheduling, not the host user name',
            'In production, avoid relying on substitute sender (*.sfcustomeremail.com)'
        };
    }

    public class EmailDeliverabilitySummary {
        @AuraEnabled public String status;
        @AuraEnabled public String statusLabel;
        @AuraEnabled public String detail;
        @AuraEnabled public String guidance;
        @AuraEnabled public String setupUrl;
        @AuraEnabled public String deliverabilitySetupUrl;
        @AuraEnabled public Integer verifiedCount;
        @AuraEnabled public Integer unverifiedCount;
        @AuraEnabled public List<String> verifiedAddresses;
        @AuraEnabled public List<String> checklistItems;
        @AuraEnabled public Boolean isSandbox;
        @AuraEnabled public Boolean substituteSenderOnly;
        @AuraEnabled public String senderDisplayName;
    }
}
