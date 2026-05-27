const helpers = require('../pageobjects/helpers');

const COMP = 'c-schedule-manager';

describe('Schedule Manager', () => {
    before(async () => {
        await browser.url('/lightning/n/Schedule_Manager');
        await browser.pause(5000);
        await helpers.waitForShadowElement(COMP, 'lightning-card');
    });

    it('should display the My Schedules heading', async () => {
        const hasHeading = await browser.execute((host) => {
            const comp = document.querySelector(host);
            if (!comp?.shadowRoot) return false;
            const card = comp.shadowRoot.querySelector('lightning-card');
            return card?.title === 'My Schedules';
        }, COMP);
        expect(hasHeading).toBe(true);
    });

    it('should show existing schedules', async () => {
        const count = await helpers.getShadowElementCount(COMP, '.slds-box');
        expect(count).toBeGreaterThan(0);
    });

    it('should display times in human-readable format (not milliseconds)', async () => {
        const pageText = await helpers.getShadowText(COMP, '.slds-box');
        expect(pageText).not.toContain('32400000');
        const hasFormattedTime = /\d{1,2}:\d{2}\s*(AM|PM)/i.test(pageText);
        expect(hasFormattedTime).toBe(true);
    });

    it('should open New Schedule modal when button is clicked', async () => {
        await helpers.clickShadowElement(COMP, 'lightning-button[variant="brand"]');
        await browser.pause(1000);
        const hasModal = await browser.execute((host) => {
            const el = document.querySelector(host);
            return el?.shadowRoot?.querySelector('.slds-modal') !== null;
        }, COMP);
        expect(hasModal).toBe(true);
    });

    it('should create a new schedule', async () => {
        await helpers.fillShadowInput(COMP, 'Schedule Name', 'WDIO Test Schedule');

        await browser.execute((host) => {
            const comp = document.querySelector(host);
            const combo = comp.shadowRoot.querySelector('lightning-combobox');
            if (combo) {
                combo.value = 'America/Chicago';
                combo.dispatchEvent(new CustomEvent('change', {
                    detail: { value: 'America/Chicago' },
                    bubbles: true, composed: true
                }));
            }
        }, COMP);
        await browser.pause(500);

        await browser.execute((host) => {
            const comp = document.querySelector(host);
            const buttons = comp.shadowRoot.querySelectorAll('lightning-button');
            for (const btn of buttons) {
                if (btn.label === 'Create') { btn.click(); break; }
            }
        }, COMP);
        await browser.pause(5000);

        const hasModal = await browser.execute((host) => {
            return document.querySelector(host)?.shadowRoot?.querySelector('.slds-modal') !== null;
        }, COMP);
        expect(hasModal).toBe(false);

        const hasSchedule = await browser.execute((host) => {
            return document.querySelector(host)?.shadowRoot?.textContent?.includes('WDIO Test Schedule') || false;
        }, COMP);
        expect(hasSchedule).toBe(true);
    });
});
