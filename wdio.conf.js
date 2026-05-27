const path = require('path');
const { execSync } = require('child_process');

function getFrontdoorUrl() {
    if (process.env.SF_FRONTDOOR_URL) return process.env.SF_FRONTDOOR_URL;
    return null;
}

function getInstanceUrl() {
    if (process.env.SF_INSTANCE_URL) return process.env.SF_INSTANCE_URL;
    const frontdoor = getFrontdoorUrl();
    if (frontdoor) {
        const url = new URL(frontdoor);
        return url.origin.replace('.my.salesforce.com', '.lightning.force.com');
    }
    return '';
}

exports.config = {
    runner: 'local',
    specs: ['./test/e2e/specs/**/*.spec.js'],
    maxInstances: 1,
    capabilities: [{
        browserName: 'chrome',
        'goog:chromeOptions': {
            args: process.env.HEADLESS === 'true'
                ? ['--headless=new', '--disable-gpu', '--window-size=1920,1080', '--no-sandbox', '--disable-dev-shm-usage']
                : ['--window-size=1920,1080']
        },
        'wdio:chromedriverOptions': {
            allowedIps: [''],
            allowedOrigins: ['*']
        }
    }],
    logLevel: 'warn',
    bail: 0,
    baseUrl: getInstanceUrl(),
    waitforTimeout: 30000,
    connectionRetryTimeout: 120000,
    connectionRetryCount: 3,
    services: [],
    automationProtocol: 'webdriver',
    framework: 'mocha',
    reporters: [
        'spec',
        ['junit', {
            outputDir: './test/e2e/results',
            outputFileFormat: function (options) {
                return `e2e-results-${options.cid}.xml`;
            }
        }]
    ],
    mochaOpts: {
        ui: 'bdd',
        timeout: 120000
    },

    async before() {
        await loginToSalesforce();
    }
};

async function loginToSalesforce() {
    const frontdoorUrl = getFrontdoorUrl();
    if (frontdoorUrl) {
        await browser.url(frontdoorUrl);
        await browser.waitUntil(
            async () => (await browser.getUrl()).includes('lightning'),
            { timeout: 30000, timeoutMsg: 'Failed to authenticate via frontdoor URL' }
        );
        return;
    }

    const instanceUrl = process.env.SF_INSTANCE_URL;
    const username = process.env.SF_USERNAME;
    const password = process.env.SF_PASSWORD;

    if (!instanceUrl || !username || !password) {
        throw new Error('Set SF_FRONTDOOR_URL or SF_INSTANCE_URL + SF_USERNAME + SF_PASSWORD');
    }

    await browser.url(instanceUrl);
    const usernameInput = await $('#username');
    const passwordInput = await $('#password');
    const loginBtn = await $('#Login');

    await usernameInput.setValue(username);
    await passwordInput.setValue(password);
    await loginBtn.click();

    await browser.waitUntil(
        async () => (await browser.getUrl()).includes('lightning'),
        { timeout: 30000, timeoutMsg: 'Login failed - did not reach Lightning Experience' }
    );
}
