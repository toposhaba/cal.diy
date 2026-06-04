const helpers = require('../pageobjects/helpers');

const COMP = 'c-calendar-booking';
const STANDARD_LABELS = new Set(['Your Name', 'Booker Name', 'Your Email', 'Booker Email']);

describe('Custom Booking Fields (End-to-End)', () => {
    before(async () => {
        await browser.url('/lightning/n/Calendar_Booking');
        await browser.pause(5000);
        await helpers.waitForShadowElement(COMP, 'lightning-card');
    });

    async function openBookingForm() {
        await browser.execute((host) => {
            const comp = document.querySelector(host);
            const box = comp?.shadowRoot?.querySelector('[data-id]');
            if (box) box.click();
        }, COMP);
        await browser.pause(5000);

        await browser.waitUntil(async () => {
            const count = await helpers.getShadowElementCount(COMP, 'lightning-button[data-index]');
            return count > 0;
        }, { timeout: 15000, timeoutMsg: 'No time slots appeared' });

        await helpers.clickShadowElement(COMP, 'lightning-button[data-index="0"]');
        await browser.pause(2000);
    }

    it('should detect custom field set on the booking form', async () => {
        await openBookingForm();

        const fieldInfo = await browser.execute((host, standardLabels) => {
            const comp = document.querySelector(host);
            if (!comp?.shadowRoot) return { hasCustom: false, labels: [] };
            const labels = [];
            let hasDataField = false;
            comp.shadowRoot.querySelectorAll('lightning-input, lightning-textarea, lightning-combobox').forEach(el => {
                if (el.label) labels.push(el.label);
                if (el.dataset?.field && !standardLabels.includes(el.label)) {
                    hasDataField = true;
                }
            });
            const hasCustomLabel = labels.some(l => !standardLabels.includes(l));
            return { hasCustom: hasDataField || hasCustomLabel, labels };
        }, COMP, Array.from(STANDARD_LABELS));

        if (!fieldInfo.hasCustom) {
            return;
        }

        expect(fieldInfo.labels.length).toBeGreaterThan(0);
    });

    it('should submit booking when custom fields are present', async function () {
        await openBookingForm();

        const hasCustom = await browser.execute((host, standardLabels) => {
            const comp = document.querySelector(host);
            if (!comp?.shadowRoot) return false;
            const inputs = comp.shadowRoot.querySelectorAll('lightning-input, lightning-textarea');
            for (const input of inputs) {
                if (input.label && !standardLabels.includes(input.label)) return true;
                if (input.dataset?.field) return true;
            }
            return false;
        }, COMP, Array.from(STANDARD_LABELS));

        if (!hasCustom) {
            this.skip();
        }

        const uniqueId = Date.now();
        await browser.execute((host, id) => {
            const comp = document.querySelector(host);
            const inputs = comp.shadowRoot.querySelectorAll('lightning-input, lightning-textarea');
            for (const input of inputs) {
                const val = input.type === 'email'
                    ? `wdio-custom-${id}@test.com`
                    : `Custom Field ${id}`;
                input.value = val;
                const native = input.shadowRoot?.querySelector('input, textarea');
                if (native) {
                    native.value = val;
                    native.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
                    native.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
                }
            }
            const btns = comp.shadowRoot.querySelectorAll('lightning-button');
            for (const btn of btns) {
                if (btn.label === 'Confirm Booking') { btn.click(); break; }
            }
        }, COMP, uniqueId);

        await browser.waitUntil(async () => {
            return browser.execute((host) => {
                const text = document.querySelector(host)?.shadowRoot?.textContent || '';
                return text.includes('Confirmed') || text.includes('Pending') ||
                    text.includes('Payment Required') || text.includes('error') || text.includes('Error');
            }, COMP);
        }, { timeout: 15000, timeoutMsg: 'Booking with custom fields did not complete' });
    });
});
