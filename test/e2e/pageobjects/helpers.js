class SalesforceHelpers {
    async navigateToApp(appName) {
        const appLauncher = await $('button[title="App Launcher"]');
        if (!await appLauncher.isExisting()) {
            await $('div.slds-icon-waffle').click();
        } else {
            await appLauncher.click();
        }
        await browser.pause(2000);
        const searchInput = await $('input[placeholder*="Search"]');
        await searchInput.waitForDisplayed({ timeout: 10000 });
        await searchInput.setValue(appName);
        await browser.pause(2000);
        const appLink = await $(`a[data-label="${appName}"], a*=${appName}, p*=${appName}`);
        await appLink.click();
        await browser.pause(3000);
    }

    async navigateToTab(tabName) {
        let tab = await $(`a=${tabName}`);
        if (await tab.isExisting()) {
            await tab.click();
            await browser.pause(2000);
            return;
        }

        const moreBtn = await $('button[title="Show more navigation items"]');
        if (await moreBtn.isExisting()) {
            await moreBtn.click();
            await browser.pause(1000);
            const menuItem = await $(`a[role="menuitem"]=${tabName}, span=${tabName}`);
            if (await menuItem.isExisting()) {
                await menuItem.click();
                await browser.pause(2000);
                return;
            }
        }

        await browser.url(`/lightning/n/${tabName.replace(/ /g, '_')}`);
        await browser.pause(3000);
    }

    async getShadowElement(hostSelector, shadowSelector) {
        return browser.execute((host, shadow) => {
            const el = document.querySelector(host);
            if (!el || !el.shadowRoot) return null;
            return el.shadowRoot.querySelector(shadow);
        }, hostSelector, shadowSelector);
    }

    async getShadowElements(hostSelector, shadowSelector) {
        return browser.execute((host, shadow) => {
            const el = document.querySelector(host);
            if (!el || !el.shadowRoot) return [];
            return Array.from(el.shadowRoot.querySelectorAll(shadow));
        }, hostSelector, shadowSelector);
    }

    async clickShadowElement(hostSelector, shadowSelector) {
        await browser.execute((host, shadow) => {
            const el = document.querySelector(host);
            if (el && el.shadowRoot) {
                const target = el.shadowRoot.querySelector(shadow);
                if (target) target.click();
            }
        }, hostSelector, shadowSelector);
    }

    async getShadowText(hostSelector, shadowSelector) {
        return browser.execute((host, shadow) => {
            const el = document.querySelector(host);
            if (!el || !el.shadowRoot) return null;
            const target = el.shadowRoot.querySelector(shadow);
            return target ? target.textContent.trim() : null;
        }, hostSelector, shadowSelector);
    }

    async getShadowElementCount(hostSelector, shadowSelector) {
        return browser.execute((host, shadow) => {
            const el = document.querySelector(host);
            if (!el || !el.shadowRoot) return 0;
            return el.shadowRoot.querySelectorAll(shadow).length;
        }, hostSelector, shadowSelector);
    }

    async waitForShadowElement(hostSelector, shadowSelector, timeout = 15000) {
        await browser.waitUntil(async () => {
            const el = await this.getShadowElement(hostSelector, shadowSelector);
            return el !== null;
        }, { timeout, timeoutMsg: `Shadow element ${shadowSelector} in ${hostSelector} not found` });
    }

    async fillShadowInput(hostSelector, inputLabel, value) {
        await browser.execute((host, label, val) => {
            const comp = document.querySelector(host);
            if (!comp || !comp.shadowRoot) return;
            const inputs = comp.shadowRoot.querySelectorAll('lightning-input, lightning-textarea');
            for (const input of inputs) {
                if (input.label === label) {
                    input.value = val;
                    input.dispatchEvent(new CustomEvent('change', {
                        detail: { value: val },
                        bubbles: true,
                        composed: true
                    }));
                    return;
                }
            }
        }, hostSelector, inputLabel, value);
    }
}

module.exports = new SalesforceHelpers();
