@IsTest
private class EmailDeliverabilityServiceTest {

    @IsTest
    static void buildSummary_returnsDeliverabilityStatus() {
        EmailDeliverabilityService.resetTestOverrides();
        String orgUrl = URL.getOrgDomainURL().toExternalForm();

        Test.startTest();
        EmailDeliverabilityService.EmailDeliverabilitySummary summary =
            EmailDeliverabilityService.buildSummary(orgUrl);
        Test.stopTest();

        System.assertNotEquals(null, summary.status);
        System.assertNotEquals(null, summary.statusLabel);
        System.assert(summary.setupUrl.contains('OrgWideEmailAddresses'));
        System.assert(summary.deliverabilitySetupUrl.contains('Deliverability'));
        System.assertNotEquals(null, summary.isSandbox);
        System.assertEquals('Cal.DIY Scheduling', summary.senderDisplayName);
        System.assertEquals(summary.verifiedCount == 0, summary.substituteSenderOnly);
        System.assert(summary.checklistItems.size() >= 5);
    }

    @IsTest
    static void buildSummary_withVerifiedOrgWideEmail() {
        EmailDeliverabilityService.orgWideEmailsOverride = new List<OrgWideEmailAddress>{
            new OrgWideEmailAddress(Address = 'scheduling@example.com', IsVerified = true)
        };
        EmailDeliverabilityService.isSandboxOverride = false;

        EmailDeliverabilityService.EmailDeliverabilitySummary summary =
            EmailDeliverabilityService.buildSummary('https://example.my.salesforce.com');

        System.assertEquals('configured', summary.status);
        System.assertEquals(1, summary.verifiedCount);
        System.assertEquals(false, summary.substituteSenderOnly);
        System.assertEquals(1, summary.verifiedAddresses.size());
    }

    @IsTest
    static void buildSummary_withUnverifiedOrgWideEmail() {
        EmailDeliverabilityService.orgWideEmailsOverride = new List<OrgWideEmailAddress>{
            new OrgWideEmailAddress(Address = 'pending@example.com', IsVerified = false)
        };
        EmailDeliverabilityService.isSandboxOverride = false;

        EmailDeliverabilityService.EmailDeliverabilitySummary summary =
            EmailDeliverabilityService.buildSummary('https://example.my.salesforce.com');

        System.assertEquals('partial', summary.status);
        System.assertEquals(1, summary.unverifiedCount);
        System.assertEquals(true, summary.substituteSenderOnly);
    }

    @IsTest
    static void buildSummary_productionWithoutOrgWideEmail() {
        EmailDeliverabilityService.orgWideEmailsOverride = new List<OrgWideEmailAddress>();
        EmailDeliverabilityService.isSandboxOverride = false;

        EmailDeliverabilityService.EmailDeliverabilitySummary summary =
            EmailDeliverabilityService.buildSummary('https://example.my.salesforce.com');

        System.assertEquals('not_configured', summary.status);
        System.assertEquals('No org-wide email', summary.statusLabel);
    }

    @IsTest
    static void buildHealthChecks_includesDeliverabilityChecks() {
        EmailDeliverabilityService.resetTestOverrides();
        String orgUrl = URL.getOrgDomainURL().toExternalForm();

        Test.startTest();
        List<IntegrationsAdminController.HealthCheck> checks =
            EmailDeliverabilityService.buildHealthChecks(orgUrl);
        Test.stopTest();

        System.assert(checks.size() >= 1);
        Boolean hasDeliverabilityCategory = false;
        for (IntegrationsAdminController.HealthCheck hc : checks) {
            if (hc.category == 'Email Deliverability') {
                hasDeliverabilityCategory = true;
                System.assertNotEquals(null, hc.setupUrl);
            }
        }
        System.assert(hasDeliverabilityCategory);
    }

    @IsTest
    static void buildHealthChecks_withVerifiedOrgWideEmail() {
        EmailDeliverabilityService.orgWideEmailsOverride = new List<OrgWideEmailAddress>{
            new OrgWideEmailAddress(Address = 'scheduling@example.com', IsVerified = true),
            new OrgWideEmailAddress(Address = 'pending@example.com', IsVerified = false)
        };
        EmailDeliverabilityService.isSandboxOverride = false;

        List<IntegrationsAdminController.HealthCheck> checks =
            EmailDeliverabilityService.buildHealthChecks('https://example.my.salesforce.com');

        System.assertEquals(2, checks.size());
        System.assertEquals('Unverified org-wide email addresses', checks[0].title);
        System.assertEquals('Confirm Deliverability access level', checks[1].title);
    }

    @IsTest
    static void buildChecklist_returnsSetupSteps() {
        List<String> checklist = EmailDeliverabilityService.buildChecklist();
        System.assert(checklist.size() >= 5);
        System.assert(checklist[0].contains('Organization-Wide Email'));
    }
}
