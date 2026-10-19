import { LightningElement, api, track } from 'lwc';
import getAddresses from '@salesforce/apex/MultipleAddressDatatableController.getAddresses';
import getAddressesByOpportunity from '@salesforce/apex/MultipleAddressDatatableController.getAddressesByOpportunity';
import getAddressesByProposal from '@salesforce/apex/MultipleAddressDatatableController.getAddressesByProposal';
import getAccountIdFromQuote from '@salesforce/apex/MultipleAddressDatatableController.getAccountIdFromQuote';
import getAccountIdFromOpportunity from '@salesforce/apex/MultipleAddressDatatableController.getAccountIdFromOpportunity';
import tagAddressWithRecord from '@salesforce/apex/MultipleAddressDatatableController.tagAddressWithRecord';
import setPrimaryAddress from '@salesforce/apex/MultipleAddressDatatableController.setPrimaryAddress';
import updateAddressDetails from '@salesforce/apex/MultipleAddressDatatableController.updateAddressDetails';
import deleteAddress from '@salesforce/apex/MultipleAddressDatatableController.deleteAddress';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class MultipleAddressDatatable extends LightningElement {
    @api recordId;
    @track addresses = [];
    error;
    @track sortedBy = '';
    @track sortDirection = 'asc';
    @track addressList = [];
    @track primaryAddressId;
    @track accountId;
    @track recordType = 'account';
    @track isModalOpen = false;
    @track isLoading = true;
    @track isSaving = false;
    @track newStreet = '';
    @track newCity = '';
    @track newState = '';
    @track newPostalCode = '';
    @track newCountry = '';
    @track isDeleteModalOpen = false;
    addressIdToDelete = null;

    get sortArrow() {
        return this.sortDirection === 'asc' ? '▲' : '▼';
    }

    get noAddressesFound() {
        return !(this.addresses && this.addresses.length > 0);
    }

    get isSortedPrimary() {
        return this.sortedBy === 'isPrimary';
    }
    get isSortedAddressType() {
        return this.sortedBy === 'AddressType';
    }
    get isSortedStreet() {
        return this.sortedBy === 'Street';
    }
    get isSortedCity() {
        return this.sortedBy === 'City';
    }
    get isSortedState() {
        return this.sortedBy === 'State';
    }
    get isSortedPostalCode() {
        return this.sortedBy === 'PostalCode';
    }

    connectedCallback() {
        if (this.recordId.startsWith('0Q0')) {
            this.recordType = 'quote';
            getAccountIdFromQuote({ quoteId: this.recordId })
                .then(accountId => {
                    this.accountId = accountId;
                })
                .catch(error => {
                    this.error = error?.body?.message || error.message;
                    console.error(error);
                });
            this.setAddressData(getAddressesByProposal({ quoteId: this.recordId }));
        } else if (this.recordId.startsWith('006')) {
            this.recordType = 'opportunity';
            getAccountIdFromOpportunity({ opportunityId: this.recordId })
                .then(accountId => {
                    this.accountId = accountId;
                })
                .catch(error => {
                    this.error = error?.body?.message || error.message;
                    console.error(error);
                });
            this.setAddressData(getAddressesByOpportunity({ opportunityId: this.recordId }));
        } else {
            this.recordType = 'account';
            this.accountId = this.recordId;
            this.setAddressData(getAddresses({ accountId: this.recordId }));
        }
    }

    setAddressData(addressesPromise) {
        this.isLoading = true;
        addressesPromise
            .then(addresses => {
                this.addresses = addresses.map(addr => ({
                    ...addr,
                    isPrimary: addr.Primary_Address__c === true
                }));
                this.addressList = this.addresses;
                const existingPrimary = this.addresses.find(addr => addr.isPrimary);
                this.primaryAddressId = existingPrimary ? existingPrimary.Id : null;
            })
            .catch(error => {
                this.error = error?.body?.message || error.message;
                console.error(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleNewButtonSave(event) {
        // Actual success/failure is handled by the form's onsuccess (handleSuccess)
        // and onerror (handleFormError) callbacks below, once the save result is known.
        console.log('handleNewButtonSave: submitting address form');
        const form = this.template.querySelector('[data-id="addressForm"]');
        if (form) {
            this.isSaving = true;
            form.submit();
        } else {
            console.error('handleNewButtonSave: addressForm not found in template');
            this.showToast('Error', 'Form not found', 'error');
        }
    }

    handleFormError(event) {
        // Log the full error detail (including per-field errors) so the real cause
        // is visible in the browser console, not just a generic toast message.
        console.error('handleFormError: address save failed', JSON.stringify(event.detail));
        this.isSaving = false;
        const fieldErrors = event.detail?.output?.fieldErrors;
        let message = event.detail?.message || event.detail?.detail || 'Error creating address';
        if (fieldErrors && Object.keys(fieldErrors).length > 0) {
            message = Object.entries(fieldErrors)
                .map(([field, errs]) => `${field}: ${errs.map(e => e.message).join(', ')}`)
                .join(' | ');
        }
        this.showToast('Error', message, 'error');
    }

    handleSort(event) {
        const field = event.currentTarget.dataset.field;

        const isSameField = this.sortedBy === field;
        this.sortDirection = isSameField && this.sortDirection === 'asc' ? 'desc' : 'asc';
        this.sortedBy = field;

        const sorted = [...this.addresses].sort((a, b) => {
            let aVal = a[field];
            let bVal = b[field];

            if (typeof aVal === 'string') aVal = aVal.toLowerCase();
            if (typeof bVal === 'string') bVal = bVal.toLowerCase();

            if (aVal === bVal) return 0;
            return (aVal > bVal ? 1 : -1) * (this.sortDirection === 'asc' ? 1 : -1);
        });

        this.addresses = sorted;
    }

    handlePrimaryChange(event) {
        const selectedId = event.target.dataset.id;
        const checked = event.target.checked;

        this.addresses = this.addresses.map(addr => ({
            ...addr,
            isPrimary: addr.Id === selectedId ? checked : false
        }));

        if (checked) {
            this.primaryAddressId = selectedId;
            this.syncPrimaryAddress(selectedId);
        } else if (this.primaryAddressId === selectedId) {
            this.primaryAddressId = null;
        }
    }

    // Primary is Account-wide: this clears/sets the flag across every address tied to the
    // Account (not just this view's scoped list) and cascades the Billing Address to the
    // Account and every Quote under it, so Account/Opportunity/Proposal views always agree.
    syncPrimaryAddress(addressId) {
        setPrimaryAddress({
            primaryAddressId: addressId,
            accountId: this.accountId
        }).catch(error => {
            console.error(error);
            this.showToast('Error', 'Error syncing primary address', 'error');
        });
    }

    handleFieldChange(event) {
        const addressId = event.target.dataset.id;
        const field = event.target.dataset.field;
        this.updateAddressField(addressId, field, event.target.value);
    }

    updateAddressField(addressId, field, value) {
        this.addresses = this.addresses.map(addr =>
            addr.Id === addressId ? { ...addr, [field]: value } : addr
        );
        this.addressList = this.addresses;

        const updated = this.addresses.find(addr => addr.Id === addressId);
        updateAddressDetails({
            addressId: addressId,
            addressType: updated.AddressType,
            street: updated.Street,
            city: updated.City,
            state: updated.State,
            postalCode: updated.PostalCode
        })
            .then(() => {
                if (updated.isPrimary) {
                    this.syncPrimaryAddress(addressId);
                }
            })
            .catch(error => {
                console.error(error);
                this.showToast('Error', 'Error saving address', 'error');
            });
    }

    handleRefresh() {
        // Primary and inline field edits already auto-save; this just re-renders
        // the page so the Account/Quote's Billing Address reflects the latest change.
        eval("$A.get('e.force:refreshView').fire();");
    }

    handleDeleteClick(event) {
        const addressId = event.target.dataset.id;
        const address = this.addresses.find(addr => addr.Id === addressId);
        if (address && address.isPrimary) {
            this.showToast('Error', 'Please select another Primary address before deleting this one.', 'error');
            return;
        }
        this.addressIdToDelete = addressId;
        this.isDeleteModalOpen = true;
    }

    cancelDelete() {
        this.isDeleteModalOpen = false;
        this.addressIdToDelete = null;
    }

    confirmDelete() {
        const addressId = this.addressIdToDelete;
        this.isDeleteModalOpen = false;

        deleteAddress({ addressId })
            .then(() => {
                this.addresses = this.addresses.filter(addr => addr.Id !== addressId);
                this.addressList = this.addresses;
                this.showToast('Success', 'Address deleted successfully', 'success');
                eval("$A.get('e.force:refreshView').fire();");
            })
            .catch(error => {
                console.error(error);
                const message = error?.body?.message || 'Error deleting address';
                this.showToast('Error', message, 'error');
            })
            .finally(() => {
                this.addressIdToDelete = null;
            });
    }

    openModal() {
        this.isModalOpen = true;
        this.isSaving = false;
        this.resetAddressLookup();
    }

    closeModal() {
        this.isModalOpen = false;
        this.isSaving = false;
    }

    resetAddressLookup() {
        this.newStreet = '';
        this.newCity = '';
        this.newState = '';
        this.newPostalCode = '';
        this.newCountry = '';
    }

    handleAddressLookupChange(event) {
        this.newStreet = event.detail.street;
        this.newCity = event.detail.city;
        this.newState = event.detail.province;
        this.newPostalCode = event.detail.postalCode;
        this.newCountry = event.detail.country;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    refreshViewAndCloseModal() {
        eval("$A.get('e.force:refreshView').fire();");
        this.closeModal();
    }

    handleSuccess(event) {
        console.log('handleSuccess: address created', event.detail.id);

        // The record is already saved at this point (event.detail.id proves it) -
        // close the modal and confirm success before doing any further bookkeeping,
        // so a bug below can never make a successful save look like it failed.
        this.isSaving = false;
        this.isModalOpen = false;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Address created successfully',
                variant: 'success',
            })
        );

        try {
            const newAddress = event.detail.fields;

            const newAddressObj = {
                Id: event.detail.id,
                Street: newAddress.Street?.value,
                City: newAddress.City?.value,
                State: newAddress.State?.value,
                PostalCode: newAddress.PostalCode?.value,
                Country: newAddress.Country?.value,
                AddressType: newAddress.AddressType?.value,
                LocationType: newAddress.LocationType?.value,
                isPrimary: newAddress.Primary_Address__c?.value === true,
            };
            if (newAddress.Primary_Address__c === undefined) {
                console.warn('handleSuccess: Primary_Address__c was not present in the returned fields map', newAddress);
            }

            // Add new address to the addresses list reactively
            if (newAddressObj.isPrimary) {
                this.addresses = this.addresses.map(addr => ({ ...addr, isPrimary: false }));
                this.primaryAddressId = newAddressObj.Id;
            }
            this.addresses = [...this.addresses, newAddressObj];
            this.addressList = this.addresses;

            if (newAddressObj.isPrimary) {
                this.syncPrimaryAddress(newAddressObj.Id);
            }

            if (this.recordType === 'opportunity' || this.recordType === 'quote') {
                tagAddressWithRecord({
                    addressId: event.detail.id,
                    opportunityId: this.recordType === 'opportunity' ? this.recordId : null,
                    quoteId: this.recordType === 'quote' ? this.recordId : null
                }).catch(error => {
                    console.error(error);
                });
            }
        } catch (error) {
            console.error('handleSuccess: error while processing the newly created address', error);
        }

        eval("$A.get('e.force:refreshView').fire();");
    }
}
