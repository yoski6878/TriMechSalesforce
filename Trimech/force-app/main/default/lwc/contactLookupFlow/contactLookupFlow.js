import { LightningElement, api, track, wire } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import searchContacts from '@salesforce/apex/ContactSelector.searchContacts';
import getAccountIdFromOpportunity from '@salesforce/apex/ContactSelector.getAccountIdFromOpportunity';
import getContactById from '@salesforce/apex/ContactSelector.getContactById';
import getContactsByIds from '@salesforce/apex/ContactSelector.getContactsByIds';

export default class ContactLookupFlow extends LightningElement {
    @api recordId; // Opportunity Id (required) — scopes search to its Account
    @api value; // Single-select: bound Contact Id (bidirectional)
    @api values = []; // Multi-select: bound Contact Id collection (bidirectional)
    @api allowMultiselect = false;
    @api fieldLabel = 'Contact';
    @api required = false;

    @track searchTerm = '';
    @track hasValidationError = false;
    @track searchResults = [];
    @track isLoading = false;
    @track noResults = false;
    @track error;
    @track showDropdown = false;
    @track selectedContact;
    @track selectedContacts = [];

    @wire(getContactById, { contactId: '$value' })
    wiredContact({ data, error }) {
        if (this.allowMultiselect) return;
        if (error) {
            this.selectedContact = null;
            this.error = error;
        } else {
            this.selectedContact = data || null;
            if (this.selectedContact) this.error = undefined;
        }
    }

    @wire(getContactsByIds, { contactIds: '$values' })
    wiredContacts({ data, error }) {
        if (!this.allowMultiselect) return;
        if (error) {
            this.error = error;
        } else {
            this.selectedContacts = data || [];
            if (this.selectedContacts.length) this.error = undefined;
        }
    }

    get isOpportunityKnown() {
        return !!this.recordId;
    }

    get disabledInput() {
        return !this.isOpportunityKnown;
    }

    get errorMessage() {
        if (!this.error) return '';
        if (this.error.body && this.error.body.message) return this.error.body.message;
        if (this.error.message) return this.error.message;
        try {
            return JSON.stringify(this.error);
        } catch (e) {
            return String(this.error);
        }
    }

    get formElementClass() {
        return this.hasValidationError
            ? 'slds-form-element slds-has-error'
            : 'slds-form-element';
    }

    @api validate() {
        if (!this.required) return { isValid: true };
        const hasValue = this.allowMultiselect
            ? this.selectedContacts.length > 0
            : !!this.selectedContact;
        this.hasValidationError = !hasValue;
        return hasValue
            ? { isValid: true }
            : { isValid: false, errorMessage: `${this.fieldLabel} is required.` };
    }

    get comboboxClass() {
        const base = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
        return this.showDropdown ? `${base} slds-is-open` : base;
    }

    get selectedContactDisplay() {
        if (!this.selectedContact) return '';
        const { name, email } = this.selectedContact;
        return email ? `${name} (${email})` : name;
    }

    get hasSelectedContacts() {
        return this.selectedContacts && this.selectedContacts.length > 0;
    }

    get showSearchInput() {
        return this.allowMultiselect || !this.selectedContact;
    }

    async handleFocus() {
        if (!this.isOpportunityKnown || this.showDropdown || this.searchTerm) return;
        await this.fetchAndSearch();
    }

    handleBlur() {
        // Delay so a click on a dropdown item fires before the dropdown is hidden
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.showDropdown = false;
            this.searchResults = [];
            this.noResults = false;
        }, 150);
    }

    async handleInputChange(event) {
        this.searchTerm = event.target.value;
        if (!this.isOpportunityKnown) {
            this.searchResults = [];
            this.showDropdown = false;
            return;
        }
        await this.fetchAndSearch();
    }

    async fetchAndSearch() {
        this.isLoading = true;
        this.error = undefined;
        try {
            const accountId = await getAccountIdFromOpportunity({ opportunityId: this.recordId });
            await this.doSearch(accountId);
        } catch (e) {
            this.error = e;
            this.searchResults = [];
            this.noResults = false;
            this.showDropdown = false;
        }
        this.isLoading = false;
    }

    async doSearch(accountId) {
        try {
            const limitSize = this.searchTerm ? 25 : 5;
            const results = await searchContacts({
                accountId,
                searchTerm: this.searchTerm,
                limitSize
            });
            const filtered = this.allowMultiselect && this.selectedContacts.length
                ? results.filter(r => !this.selectedContacts.find(s => s.contactId === r.contactId))
                : results;
            this.searchResults = filtered;
            this.noResults = filtered.length === 0;
            this.showDropdown = true;
        } catch (e) {
            this.error = e;
            this.searchResults = [];
            this.noResults = false;
            this.showDropdown = false;
        }
    }

    handleSelect(event) {
        const contactId = event.currentTarget.dataset.id;
        const picked = this.searchResults.find(c => c.contactId === contactId);
        if (this.allowMultiselect) {
            if (picked && !this.selectedContacts.find(c => c.contactId === contactId)) {
                this.selectedContacts = [...this.selectedContacts, picked];
            }
            const newValues = this.selectedContacts.map(c => c.contactId);
            this.searchTerm = '';
            this.searchResults = [];
            this.showDropdown = false;
            this.hasValidationError = false;
            this.dispatchEvent(new FlowAttributeChangeEvent('values', newValues));
        } else {
            if (picked) {
                this.selectedContact = picked;
            }
            this.searchTerm = '';
            this.searchResults = [];
            this.showDropdown = false;
            this.hasValidationError = false;
            this.dispatchEvent(new FlowAttributeChangeEvent('value', contactId));
        }
    }

    handleClear() {
        this.selectedContact = null;
        this.searchTerm = '';
        this.searchResults = [];
        this.showDropdown = false;
        this.error = undefined;
        this.dispatchEvent(new FlowAttributeChangeEvent('value', null));
    }

    handleRemovePill(event) {
        const contactId = event.currentTarget.dataset.id;
        this.selectedContacts = this.selectedContacts.filter(c => c.contactId !== contactId);
        const newValues = this.selectedContacts.map(c => c.contactId);
        this.dispatchEvent(new FlowAttributeChangeEvent('values', newValues));
    }
}