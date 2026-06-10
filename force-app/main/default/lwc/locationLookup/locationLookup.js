import { LightningElement, api } from 'lwc';

export default class LocationLookup extends LightningElement {
    @api label = 'Location';
    @api value = '';
    @api apiKey;
    @api required = false;

    scriptLoaded = false;
    autocomplete = null;

    get usePlaces() {
        return !!this.apiKey;
    }

    renderedCallback() {
        if (this.usePlaces && !this.scriptLoaded) {
            this.scriptLoaded = true;
            this.loadGoogleMaps();
        }
    }

    loadGoogleMaps() {
        if (window.google && window.google.maps && window.google.maps.places) {
            this.initAutocomplete();
            return;
        }

        const script = document.createElement('script');
        script.src = `https://maps.googleapis.com/maps/api/js?key=${this.apiKey}&libraries=places`;
        script.async = true;
        script.defer = true;
        script.onload = () => this.initAutocomplete();
        document.head.appendChild(script);
    }

    initAutocomplete() {
        const input = this.template.querySelector('[data-id="address-input"]');
        if (!input || !window.google || !window.google.maps || !window.google.maps.places) {
            return;
        }

        if (this.autocomplete) {
            return;
        }

        this.autocomplete = new window.google.maps.places.Autocomplete(input, {
            types: ['address']
        });

        this.autocomplete.addListener('place_changed', () => {
            const place = this.autocomplete.getPlace();
            const address = place.formatted_address || input.value;
            this.dispatchLocationChange(address);
        });
    }

    handleInputChange(event) {
        this.dispatchLocationChange(event.target.value);
    }

    handleInputBlur(event) {
        if (this.usePlaces) {
            this.dispatchLocationChange(event.target.value);
        }
    }

    dispatchLocationChange(address) {
        this.dispatchEvent(new CustomEvent('locationchange', {
            detail: { value: address }
        }));
    }
}
