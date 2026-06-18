import { LightningElement, api, track, wire } from 'lwc';
import getAddresses from '@salesforce/apex/MultipleAddressDatatableController.getAddresses';
import getAccountIdFromQuote from '@salesforce/apex/MultipleAddressDatatableController.getAccountIdFromQuote';
import updateQuoteAddressesWithDetails from '@salesforce/apex/MultipleAddressDatatableController.updateQuoteAddressesWithDetails';
import updateAccountAddressesWithDetails from '@salesforce/apex/MultipleAddressDatatableController.updateAccountAddressesWithDetails';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';


export default class MultipleAddressDatatable extends LightningElement {
    @api recordId;
    @track addresses = [];
    @track columns = [];
    primaryBillingId = null;
    primaryShiftingId = null;
    error;
    @track sortedBy = '';
    @track sortDirection = 'asc';
    @track addressList = [];
    @track billingAddressId;
    @track shippingAddressId;

    get sortArrow() {
        return this.sortDirection === 'asc' ? '▲' : '▼';
    }

    get noAddressesFound() {
        return !(this.addresses && this.addresses.length > 0);
    }


    get isSortedBilling() {
        return this.sortedBy === 'isBilling';
    }
    get isSortedShipping() {
        return this.sortedBy === 'isShipping';
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

    @track accountId;

    // connectedCallback() {
    //     getAddresses({ recordId: this.recordId })
    //         .then(result => {
    //             console.log(result);
    //             this.accountId = result?.accountId;
    //             this.addresses = result?.addresses;
    //             this.addressList = result?.addresses;

    //             this.columns = [
    //                 {
    //                     label: 'Billing',
    //                     fieldName: 'isBilling',
    //                     type: 'boolean',
    //                     editable: true
    //                 },
    //                 {
    //                     label: 'Shipping',
    //                     fieldName: 'isShipping',
    //                     type: 'boolean',
    //                     editable: true
    //                 },
    //                 { label: 'AddressType', fieldName: 'Street', type: 'text' },
    //                 { label: 'Street', fieldName: 'Street', type: 'text' },
    //                 { label: 'City', fieldName: 'City', type: 'text' },
    //                 { label: 'State', fieldName: 'State', type: 'text' },
    //                 { label: 'Postal Code', fieldName: 'PostalCode', type: 'text' }
    //             ];
    //         })
    //         .catch(err => {
    //             this.error = err.body.message;
    //             console.log(err);
    //         });
    // }

    connectedCallback() {
        const isQuoteId = this.recordId.startsWith('0Q0');

        if (isQuoteId) {
            getAccountIdFromQuote({ quoteId: this.recordId })
                .then(accountId => {
                    this.accountId = accountId;
                    this.getAddressesByAccountIdAndSetData(accountId);
                })
                .catch(error => {
                    this.error = error?.body?.message || error.message;
                    console.error(error);
                });
        } else {
            this.accountId = this.recordId;
            this.getAddressesByAccountIdAndSetData(this.recordId);
        }
    }

    getAddressesByAccountIdAndSetData(accountId) {
        getAddresses({ accountId: accountId })
            .then(addresses => {
                this.addresses = addresses;
                this.addressList = addresses;
                this.initializeColumns();
            })
            .catch(error => {
                this.error = error?.body?.message || error.message;
                console.error(error);
            });
    }



    initializeColumns() {
        this.columns = [
            {
                label: 'Billing',
                fieldName: 'isBilling',
                type: 'boolean',
                editable: true
            },
            {
                label: 'Shipping',
                fieldName: 'isShipping',
                type: 'boolean',
                editable: true
            },
            { label: 'Address Type', fieldName: 'AddressType', type: 'text' },
            { label: 'Street', fieldName: 'Street', type: 'text' },
            { label: 'City', fieldName: 'City', type: 'text' },
            { label: 'State', fieldName: 'State', type: 'text' },
            { label: 'Postal Code', fieldName: 'PostalCode', type: 'text' }
        ];
    }



    handleNewButtonSave(event) {
        try{

            const form = this.template.querySelector('[data-id="addressForm"]');
            if (form) {
                form.submit(); // triggers onsuccess/onerror
                this.isModalOpen = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Address created successfully',
                        variant: 'success',
                    })
                );
                eval("$A.get('e.force:refreshView').fire();");
            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Form not found',
                        variant: 'error'
                    })
                );
            }

        }catch(error){
            console.log("Error");
            console.log(error);
        }
        
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


    handleBillingChange(event) {
        console.log('OUTPUT : handleBillingChange');
        console.log(JSON.stringify(event));
        const selectedId = event.target.dataset.id;
        this.addresses = this.addresses.map(addr => {
            const isSelected = addr.Id === selectedId && event.target.checked;
            if (isSelected) {
                this.billingAddressId = selectedId;
            }
            return {
                ...addr,
                isBilling: addr.Id === selectedId ? event.target.checked : false
            };
        });
    }

    handleShippingChange(event) {
        console.log('OUTPUT : handleShippingChange');
        console.log(JSON.stringify(event));
        const selectedId = event.target.dataset.id;
        this.addresses = this.addresses.map(addr => {
            const isSelected = addr.Id === selectedId && event.target.checked;
            if (isSelected) {
                this.shippingAddressId = selectedId;
            }
            return {
                ...addr,
                isShipping: addr.Id === selectedId ? event.target.checked : false
            };
        });
    }


    @track isModalOpen = false;

    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleSave(event){
        const isQuoteId = this.recordId.startsWith('0Q0');

        const params = {
            billingAddressId: this.billingAddressId,
            shippingAddressId: this.shippingAddressId
        };

        if (isQuoteId) {
            updateQuoteAddressesWithDetails({
                quoteId: this.recordId,
                ...params
            })
                .then(() => {
                    this.showToast('Success', 'Addresses updated successfully', 'success');
                    this.refreshViewAndCloseModal();
                    updateAccountAddressesWithDetails({
                        accountId: this.accountId,
                        ...params
                    })
                        .then(() => {
                            // this.showToast('Success', 'Account addresses updated successfully', 'success');
                            // this.refreshViewAndCloseModal();
                        })
                        .catch(error => {
                            console.error(error);
                            this.showToast('Error', 'Error updating account', 'error');
                        });
                })
                .catch(error => {
                    console.error(error);
                    this.showToast('Error', 'Error updating quote', 'error');
                });
        } else {
            updateAccountAddressesWithDetails({
                accountId: this.recordId,
                ...params
            })
                .then(() => {
                    this.showToast('Success', 'Account addresses updated successfully', 'success');
                    this.refreshViewAndCloseModal();
                })
                .catch(error => {
                    console.error(error);
                    this.showToast('Error', 'Error updating account', 'error');
                });
        }
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
        const newAddress = event.detail.fields;
        // event.detail.id has the Id of the newly created Address

        // Construct a full address object similar to existing ones,
        // you may want to include isBilling, isShipping as false initially
        const newAddressObj = {
            Id: event.detail.id,
            Street: newAddress.Street.value,
            City: newAddress.City.value,
            State: newAddress.State.value,
            PostalCode: newAddress.PostalCode.value,
            Country: newAddress.Country.value,
            AddressType: newAddress.AddressType.value,
            LocationType: newAddress.LocationType.value,
            isBilling: false,
            isShipping: false,
            // Add other fields if needed
        };

        // Add new address to the addresses list reactively
        this.addresses = [...this.addresses, newAddressObj];
        this.addressList = this.addresses;

        // Close modal if you want
        this.isModalOpen = false;

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Address created successfully',
                variant: 'success',
            })
        );

        // Refresh view if needed
        eval("$A.get('e.force:refreshView').fire();");
    }

}