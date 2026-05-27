const helpers = require('../pageobjects/helpers');

const COMP = 'c-calendar-connections';

describe('Calendar Connections', () => {
    before(async () => {
        await browser.url('/lightning/n/Calendar_Connections');
        await browser.pause(5000);
        await helpers.waitForShadowElement(COMP, 'lightning-card');
    });

    it('should display the Calendar Connections heading', async () => {
        const hasHeading = await browser.execute((host) => {
            const comp = document.querySelector(host);
            const card = comp?.shadowRoot?.querySelector('lightning-card');
            return card?.title === 'Calendar Connections';
        }, COMP);
        expect(hasHeading).toBe(true);
    });

    it('should show the Add Calendar button', async () => {
        const hasBtn = await browser.execute((host) => {
            const comp = document.querySelector(host);
            const btns = comp?.shadowRoot?.querySelectorAll('lightning-button');
            for (const btn of btns) {
                if (btn.label === 'Add Calendar') return true;
            }
            return false;
        }, COMP);
        expect(hasBtn).toBe(true);
    });

    it('should display existing connections or empty state', async () => {
        const boxCount = await helpers.getShadowElementCount(COMP, '.slds-box');
        const emptyText = await helpers.getShadowText(COMP, '.slds-text-color_weak');

        const hasContent = boxCount > 0 || (emptyText && emptyText.includes('No calendar connections'));
        expect(hasContent).toBe(true);
    });

    it('should open Add Calendar modal', async () => {
        await browser.execute((host) => {
            const comp = document.querySelector(host);
            const btns = comp?.shadowRoot?.querySelectorAll('lightning-button');
            for (const btn of btns) {
                if (btn.label === 'Add Calendar') { btn.click(); break; }
            }
        }, COMP);
        await browser.pause(1000);

        const hasModal = await browser.execute((host) => {
            return document.querySelector(host)?.shadowRoot?.querySelector('.slds-modal') !== null;
        }, COMP);
        expect(hasModal).toBe(true);
    });

    it('should show provider selection in the modal', async () => {
        const hasCombo = await browser.execute((host) => {
            return document.querySelector(host)?.shadowRoot?.querySelector('lightning-combobox') !== null;
        }, COMP);
        expect(hasCombo).toBe(true);
    });
});
