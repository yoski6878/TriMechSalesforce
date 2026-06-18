import { LightningElement, api, track } from 'lwc';

export default class HolidayMessageInput extends LightningElement {
    @track _value = '';
    @api label = 'Message';
    @api required = false;

    // Input from Flow
    @api
    get value() {
        return this._value;
    }
    set value(val) {
        this._value = typeof val === 'string' ? val : '';
        // Enforce max length defensively if Flow injects longer text
        if (this._value.length > 255) {
            this._value = this._value.substring(0, 255);
        }
    }

    // Output to Flow (maps to valueOutput in meta)
    @api valueOutput;

    connectedCallback() {
        // Initialize output with initial value so it's not blank even if user doesn't edit
        this.valueOutput = this._value;
    }

    get remainingChars() {
        const remaining = 255 - (this._value ? this._value.length : 0);
        return remaining >= 0 ? remaining : 0;
    }

    handleInput(event) {
        let incoming = event.target.value || '';
        if (incoming.length > 255) {
            incoming = incoming.substring(0, 255);
            // reflect the trimmed value back into the UI
            event.target.value = incoming;
        }
        this._value = incoming;
        this.valueOutput = this._value;

        // Dispatch change so Flow recognizes the updated output variable
        this.dispatchEvent(
            new CustomEvent('change', {
                detail: { value: this._value }
            })
        );
    }
}