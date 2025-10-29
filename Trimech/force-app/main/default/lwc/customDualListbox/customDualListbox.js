import { LightningElement, api, track } from 'lwc';

export default class CustomDualListbox extends LightningElement {
    @api label;
    @api options = [];
    @api name;
    @api selectedValues = [];

    @track isModalOpen = false;
    @track tempSelectedValues = [];

    // Compute options with "checked" property
    get processedOptions() {
        const safeSelectedValues = Array.isArray(this.selectedValues) ? this.selectedValues : []; 

        return this.options.map(option => ({
            ...option,
            checked: safeSelectedValues.includes(option.value) 
        }));
    }

    get showClear(){
        return  this.selectedValues && this.selectedValues.length > 0 ? true : false;  
    }

    get hasMoreThanFive() {
        return this.options.length > 5;
    }

    get firstFiveOptions() {
        return this.processedOptions.slice(0, 5);
    }

    get remainingOptions() {
        return this.processedOptions;
    }

    handleCheckboxChange(event) {
        const { name, value, checked } = event.target;
        let updatedValues = this.selectedValues? [...this.selectedValues] : [];

        if (checked) {
            updatedValues.push(value);
        } else {
            updatedValues = updatedValues.filter(item => item !== value);
        }

        this.selectedValues = updatedValues;
        this.dispatchSelectionChange(name, updatedValues);
    }

    clearSelection(){
        this.selectedValues = []; 
        this.dispatchSelectionChange(this.name, this.selectedValues);
    }

    handleDualListboxChange(event) {
        this.tempSelectedValues = event.detail.value;
    }

    openModal() {
        this.isModalOpen = true;
        this.tempSelectedValues = [...this.selectedValues];
    }

    closeModal() {
        this.isModalOpen = false;
    }

    applySelection() {
        this.selectedValues = [...this.tempSelectedValues];
        this.dispatchSelectionChange(this.name, this.selectedValues);
        this.closeModal();
    }

    dispatchSelectionChange(filterName, filterValue) {
        this.dispatchEvent(new CustomEvent('childselectionchange', {
            detail: { filterName, filterValue }
        }));
    }
}