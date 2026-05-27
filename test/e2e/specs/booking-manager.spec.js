const helpers = require('../pageobjects/helpers');

const COMP = 'c-booking-manager';

describe('Booking Manager', () => {
    before(async () => {
        await browser.url('/lightning/n/Booking_Manager');
        await browser.pause(5000);
        await helpers.waitForShadowElement(COMP, 'lightning-card');
    });

    it('should display the My Bookings heading', async () => {
        const hasHeading = await browser.execute((host) => {
            const comp = document.querySelector(host);
            const card = comp?.shadowRoot?.querySelector('lightning-card');
            return card?.title === 'My Bookings';
        }, COMP);
        expect(hasHeading).toBe(true);
    });

    it('should show date range filters', async () => {
        const dateInputCount = await browser.execute((host) => {
            const comp = document.querySelector(host);
            if (!comp?.shadowRoot) return 0;
            return comp.shadowRoot.querySelectorAll('lightning-input').length;
        }, COMP);
        expect(dateInputCount).toBeGreaterThanOrEqual(2);
    });

    it('should show bookings in a table', async () => {
        const hasTable = await browser.execute((host) => {
            const comp = document.querySelector(host);
            return comp?.shadowRoot?.querySelector('table') !== null;
        }, COMP);

        if (hasTable) {
            const rows = await helpers.getShadowElementCount(COMP, 'tbody tr');
            expect(rows).toBeGreaterThan(0);
        } else {
            const emptyText = await helpers.getShadowText(COMP, '.slds-text-color_weak');
            expect(emptyText).toContain('No bookings found');
        }
    });

    it('should display booking status badges', async () => {
        const hasTable = await browser.execute((host) => {
            return document.querySelector(host)?.shadowRoot?.querySelector('table') !== null;
        }, COMP);

        if (hasTable) {
            const hasBadge = await browser.execute((host) => {
                return document.querySelector(host)?.shadowRoot?.querySelector('.slds-badge') !== null;
            }, COMP);
            expect(hasBadge).toBe(true);
        }
    });

    it('should show bookings in the list', async () => {
        const hasBookings = await browser.execute((host) => {
            const comp = document.querySelector(host);
            const text = comp?.shadowRoot?.textContent || '';
            return text.includes('Accepted') || text.includes('Cancelled') || text.includes('Pending');
        }, COMP);
        expect(hasBookings).toBe(true);
    });
});
