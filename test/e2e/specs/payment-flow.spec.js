const helpers = require('../pageobjects/helpers');

const COMP = 'c-calendar-booking';

function stripeConfigured() {
    return Boolean(
        process.env.STRIPE_PUBLISHABLE_KEY ||
        process.env.STRIPE_SECRET_KEY ||
        process.env.E2E_STRIPE_ENABLED === 'true'
    );
}

describe('Payment Flow (End-to-End)', () => {
    before(function () {
        if (!stripeConfigured()) {
            this.skip();
        }
    });

    before(async () => {
        await browser.url('/lightning/n/Calendar_Booking');
        await browser.pause(5000);
        await helpers.waitForShadowElement(COMP, 'lightning-card');
    });

    async function selectFirstEventType() {
        await browser.execute((host) => {
            const comp = document.querySelector(host);
            const box = comp?.shadowRoot?.querySelector('[data-id]');
            if (box) box.click();
        }, COMP);
        await browser.pause(5000);
    }

    async function selectFirstSlot() {
        await browser.waitUntil(async () => {
            const count = await helpers.getShadowElementCount(COMP, 'lightning-button[data-index]');
            return count > 0;
        }, { timeout: 15000, timeoutMsg: 'No time slots appeared' });
        await helpers.clickShadowElement(COMP, 'lightning-button[data-index="0"]');
        await browser.pause(2000);
    }

    async function submitBooking() {
        const uniqueId = Date.now();
        await browser.execute((host, n, e) => {
            const comp = document.querySelector(host);
            const inputs = comp.shadowRoot.querySelectorAll('lightning-input');
            for (const input of inputs) {
                if (input.label === 'Your Name' || input.label === 'Booker Name') {
                    input.value = n;
                    const nativeInput = input.shadowRoot?.querySelector('input');
                    if (nativeInput) {
                        nativeInput.value = n;
                        nativeInput.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
                        nativeInput.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
                    }
                }
                if (input.label === 'Your Email' || input.label === 'Booker Email') {
                    input.value = e;
                    const nativeInput = input.shadowRoot?.querySelector('input');
                    if (nativeInput) {
                        nativeInput.value = e;
                        nativeInput.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
                        nativeInput.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
                    }
                }
            }
            const btns = comp.shadowRoot.querySelectorAll('lightning-button');
            for (const btn of btns) {
                if (btn.label === 'Confirm Booking') { btn.click(); break; }
            }
        }, COMP, `Payment Tester ${uniqueId}`, `wdio-pay-${uniqueId}@test.com`);
    }

    it('should reach payment required or skip when no paid event types', async () => {
        await selectFirstEventType();
        await selectFirstSlot();
        await submitBooking();

        await browser.waitUntil(async () => {
            return browser.execute((host) => {
                const text = document.querySelector(host)?.shadowRoot?.textContent || '';
                return text.includes('Payment Required') ||
                    text.includes('Complete payment') ||
                    text.includes('Confirmed') ||
                    text.includes('Pending') ||
                    text.includes('error') ||
                    text.includes('Error');
            }, COMP);
        }, { timeout: 20000, timeoutMsg: 'Booking did not complete' });

        const paymentState = await browser.execute((host) => {
            const text = document.querySelector(host)?.shadowRoot?.textContent || '';
            const hasPaymentBtn = Array.from(
                document.querySelector(host)?.shadowRoot?.querySelectorAll('lightning-button') || []
            ).some(b => b.label === 'Complete Payment');
            return {
                pendingPayment: text.includes('Payment Required') || text.includes('Complete payment'),
                hasPaymentBtn,
                freeBooking: text.includes('Confirmed') || text.includes('Pending')
            };
        }, COMP);

        if (!paymentState.pendingPayment && paymentState.freeBooking) {
            return;
        }

        expect(paymentState.pendingPayment || paymentState.hasPaymentBtn).toBe(true);
    });
});
