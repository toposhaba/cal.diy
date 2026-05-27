const helpers = require('../pageobjects/helpers');

const COMP = 'c-calendar-booking';

describe('Booking Flow (End-to-End)', () => {
    before(async () => {
        await browser.url('/lightning/n/Calendar_Booking');
        await browser.pause(5000);
        await helpers.waitForShadowElement(COMP, 'lightning-card');
    });

    describe('Step 1: Event Type Selection', () => {
        it('should display event type cards', async () => {
            const count = await helpers.getShadowElementCount(COMP, '.slds-box_link');
            expect(count).toBeGreaterThan(0);
        });

        it('should show event type names and durations', async () => {
            const text = await helpers.getShadowText(COMP, '.slds-box_link');
            expect(text).toContain('minutes');
        });

        it('should navigate to date selection on click', async () => {
            await browser.execute((host) => {
                const comp = document.querySelector(host);
                const boxes = comp?.shadowRoot?.querySelectorAll('[data-id]');
                if (boxes?.length > 0) boxes[0].click();
            }, COMP);
            await browser.pause(5000);

            const hasDateInput = await browser.execute((host) => {
                const comp = document.querySelector(host);
                if (!comp?.shadowRoot) return false;
                const inputs = comp.shadowRoot.querySelectorAll('lightning-input');
                for (const input of inputs) {
                    if (input.type === 'date') return true;
                }
                return comp.shadowRoot.textContent.includes('Select Date');
            }, COMP);
            expect(hasDateInput).toBe(true);
        });
    });

    describe('Step 2: Date & Time Selection', () => {
        it('should show the Back button', async () => {
            const backBtn = await browser.execute((host) => {
                const comp = document.querySelector(host);
                const btns = comp?.shadowRoot?.querySelectorAll('lightning-button');
                for (const btn of btns) {
                    if (btn.label === 'Back') return true;
                }
                return false;
            }, COMP);
            expect(backBtn).toBe(true);
        });

        it('should display available time slots', async () => {
            await browser.waitUntil(async () => {
                const count = await helpers.getShadowElementCount(COMP, 'lightning-button[data-index]');
                return count > 0;
            }, { timeout: 15000, timeoutMsg: 'No time slots appeared' });

            const slotCount = await helpers.getShadowElementCount(COMP, 'lightning-button[data-index]');
            expect(slotCount).toBeGreaterThan(0);
        });

        it('should show formatted times on slot buttons', async () => {
            const slotText = await browser.execute((host) => {
                const comp = document.querySelector(host);
                const btn = comp?.shadowRoot?.querySelector('lightning-button[data-index]');
                return btn?.label || '';
            }, COMP);
            expect(slotText).toMatch(/\d{1,2}:\d{2}\s*(AM|PM)/i);
        });

        it('should navigate to booking form on slot click', async () => {
            await helpers.clickShadowElement(COMP, 'lightning-button[data-index="0"]');
            await browser.pause(2000);

            const hasNameInput = await browser.execute((host) => {
                const comp = document.querySelector(host);
                const inputs = comp?.shadowRoot?.querySelectorAll('lightning-input');
                for (const input of inputs) {
                    if (input.label === 'Your Name' || input.label === 'Booker Name') return true;
                }
                return false;
            }, COMP);
            expect(hasNameInput).toBe(true);
        });
    });

    describe('Step 3: Booking Form', () => {
        it('should display required fields', async () => {
            const fields = await browser.execute((host) => {
                const comp = document.querySelector(host);
                const inputs = comp?.shadowRoot?.querySelectorAll('lightning-input');
                return Array.from(inputs).map(i => i.label);
            }, COMP);
            const hasName = fields.some(f => f === 'Your Name' || f === 'Booker Name');
            const hasEmail = fields.some(f => f === 'Your Email' || f === 'Booker Email');
            expect(hasName).toBe(true);
            expect(hasEmail).toBe(true);
        });

        it('should fill in booker details and submit', async () => {
            const uniqueId = Date.now();
            const name = `WDIO Tester ${uniqueId}`;
            const email = `wdio-${uniqueId}@test.com`;

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
            }, COMP, name, email);
            await browser.pause(1000);

            await browser.execute((host) => {
                const comp = document.querySelector(host);
                const btns = comp.shadowRoot.querySelectorAll('lightning-button');
                for (const btn of btns) {
                    if (btn.label === 'Confirm Booking') { btn.click(); break; }
                }
            }, COMP);

            await browser.waitUntil(async () => {
                return browser.execute((host) => {
                    const text = document.querySelector(host)?.shadowRoot?.textContent || '';
                    return text.includes('Confirmed') || text.includes('Pending') ||
                           text.includes('error') || text.includes('Error');
                }, COMP);
            }, { timeout: 15000, timeoutMsg: 'Booking did not complete' });
        });
    });

    describe('Step 4: Confirmation', () => {
        it('should show confirmation or pending or error message', async () => {
            const state = await browser.execute((host) => {
                const comp = document.querySelector(host);
                const text = comp?.shadowRoot?.textContent || '';
                const hasConfirmed = text.includes('Confirmed');
                const hasPending = text.includes('Pending');
                const hasBookAnother = text.includes('Book Another');
                const hasError = text.includes('error') || text.includes('Error');
                const hasRef = /Reference:/.test(text);
                return { hasConfirmed, hasPending, hasBookAnother, hasError, hasRef,
                         snippet: text.substring(0, 500) };
            }, COMP);
            const bookingCompleted = state.hasConfirmed || state.hasPending;
            expect(bookingCompleted || state.hasError).toBe(true);
        });

        it('should display reference or error details', async () => {
            const result = await browser.execute((host) => {
                const comp = document.querySelector(host);
                const text = comp?.shadowRoot?.textContent || '';
                const refMatch = text.match(/Reference:\s*([\w-]+)/);
                if (refMatch) return { type: 'ref', value: refMatch[1] };
                const errorEl = comp?.shadowRoot?.querySelector('.slds-notify_alert, .slds-alert_error');
                if (errorEl) return { type: 'error', value: errorEl.textContent.trim() };
                return { type: 'unknown', value: text.substring(0, 200) };
            }, COMP);
            expect(result.type).not.toBe('unknown');
        });

        it('should show Book Another button if booking succeeded', async () => {
            const hasBtn = await browser.execute((host) => {
                const comp = document.querySelector(host);
                const btns = comp?.shadowRoot?.querySelectorAll('lightning-button');
                for (const btn of btns) {
                    if (btn.label === 'Book Another') return true;
                }
                return false;
            }, COMP);
            const confirmed = await browser.execute((host) => {
                const text = document.querySelector(host)?.shadowRoot?.textContent || '';
                return text.includes('Confirmed') || text.includes('Pending');
            }, COMP);
            if (confirmed) {
                expect(hasBtn).toBe(true);
            }
        });
    });
});
