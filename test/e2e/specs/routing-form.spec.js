const helpers = require('../pageobjects/helpers');

const COMP = 'c-routing-form';

describe('Routing Form (End-to-End)', () => {
    before(async () => {
        await browser.url('/lightning/n/Routing_Booking');
        await browser.pause(5000);
        await helpers.waitForShadowElement(COMP, 'lightning-card');
    });

    it('should display the routing form card', async () => {
        const title = await browser.execute((host) => {
            const comp = document.querySelector(host);
            const card = comp?.shadowRoot?.querySelector('lightning-card');
            return card?.title || '';
        }, COMP);
        expect(title).toContain('Meeting');
    });

    it('should show form selection or an empty state', async () => {
        const state = await browser.execute((host) => {
            const comp = document.querySelector(host);
            const text = comp?.shadowRoot?.textContent || '';
            const formLinks = comp?.shadowRoot?.querySelectorAll('.slds-box_link')?.length || 0;
            const noForms = text.includes('No routing forms configured');
            return { formLinks, noForms };
        }, COMP);
        expect(state.formLinks > 0 || state.noForms).toBe(true);
    });

    it('should advance to questions when a form is selected', async () => {
        const formCount = await helpers.getShadowElementCount(COMP, '.slds-box_link');
        if (formCount === 0) {
            return;
        }

        await browser.execute((host) => {
            const comp = document.querySelector(host);
            const box = comp?.shadowRoot?.querySelector('.slds-box_link');
            if (box) box.click();
        }, COMP);
        await browser.pause(3000);

        const hasContinue = await browser.execute((host) => {
            const comp = document.querySelector(host);
            const btns = comp?.shadowRoot?.querySelectorAll('lightning-button');
            for (const btn of btns) {
                if (btn.label === 'Continue') return true;
            }
            return false;
        }, COMP);
        expect(hasContinue).toBe(true);
    });
});
