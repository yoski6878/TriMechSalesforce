import { LightningElement, track, api } from 'lwc';
import getProductData from '@salesforce/apex/AddProductToOpportunityController.getProductData';
import createOpportunityLineItem from '@salesforce/apex/AddProductToOpportunityController.createOpportunityLineItem';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
const TIMEOUT_DURATION = 300;

export default class AddProductToOpportunity extends LightningElement {
    @api recordId;
    @track isSpinner = false;
    @track productDataList = [];
    @track parentChildProductMap = {};
    @track dataTableAllDataList = [];
    @track dataTableFilterDataList = [];
    @track searchValue = '';
    @track displayFilter = false;
    @track oldFilterValue = 'All';
    @track selectedType = 'All';
    @track selectedProducts = [];
    @track newProductList = [];
    @track firstPage = true;
    @track secondPage = false;
    @track draftValues = [];

    firstTableColumns = [
        {
            label: 'Product Name',
            fieldName: 'pricebookEntryLink',
            type: 'url',
            typeAttributes: { 
                label: { fieldName: 'productName' }, 
                target: '_blank' 
            }
        },
        { 
            label: 'Product Code', 
            fieldName: 'productCode', 
            type: 'String'
        },
        { 
            label: 'List Price', 
            fieldName: 'listPrice', 
            type: 'currency'
        },
        { 
            label: 'Product Description', 
            fieldName: 'productDesc', 
            type: 'String'
        },
        { 
            label: 'Product Family', 
            fieldName: 'productFamily', 
            type: 'String'
        },
        { 
            label: 'Product Type', 
            fieldName: 'type', 
            type: 'String'
        },
    ];

    secondTableColumns = [
        {
            label: 'Product Name',
            fieldName: 'pricebookEntryLink',
            type: 'url',
            typeAttributes: { 
                label: { fieldName: 'productName' }, 
                target: '_blank' 
            }
        },
        { 
            label: 'Quantity', 
            fieldName: 'quantity', 
            type: 'number',
            editable: true 
        },
        { 
            label: 'Sales Price', 
            fieldName: 'listPrice', 
            type: 'currency',
            editable: true 
        },
        { 
            label: 'Date', 
            fieldName: 'date', 
            type: 'date-local',
            editable: true 
        },
        { 
            label: 'Line Description', 
            fieldName: 'lineDesc', 
            type: 'String',
            editable: true 
        },
        { 
            label: 'Product Type', 
            fieldName: 'type', 
            type: 'String'
        },
        {
            type: "button-icon", 
            label: '', 
            initialWidth: 70, 
            typeAttributes: {
                label: '',
                name: 'Delete',
                title: 'Delete',
                disabled: false,
                value: 'Delete',
                iconPosition: 'left',
                iconName:'utility:delete',
                variant:'Neutral',
            },
        }
    ];

    get modalHeader(){
        return this.firstPage ? 'Add Products' : 'Edit Selected Products';
    }

    get tableWidth(){
        return this.displayFilter ? 'width: 70%;' : 'width: 100%;';
    }

    get radioOptions() {
        return [
            { label: 'All', value: 'All' },
            { label: 'Parent', value: 'Parent' },
            { label: 'Child', value: 'Child' },
        ];
    }

    get disableNext(){
        return this.selectedProducts.length > 0 ? false : true;
    }

    // get disableSave(){
    //     let returnValue = false;
    //     let newProductList = this.newProductList;
    //     newProductList.forEach(element => {
    //         if (!element.quantity ) {
    //             returnValue = true;
    //         } else if (element.quantity <= 0 ) {
    //             returnValue = true;
    //         }
    //     });
    //     return returnValue;
    // }

    connectedCallback() { 
        this.isSpinner = true;
        setTimeout(() => {
            this.getDataHelper();
        }, TIMEOUT_DURATION);
    }

    getDataHelper(){
        getProductData({opportunityId: this.recordId})
        .then(result => {
            this.productDataList = result;
            let dataTableAllDataList = [];
            result.forEach(element => {
                let dataTableData = {};
                dataTableData.isSelected = false;
                dataTableData.pricebookEntryLink = '/'+element.productWrap.pricebookEntryRec.Id;
                dataTableData.pricebookEntryLinkId = element.productWrap.pricebookEntryRec.Id;
                dataTableData.productId = element.productWrap.product.Id;
                dataTableData.productName = element.productWrap.product.Name;
                dataTableData.productCode = element.productWrap.product.ProductCode;
                dataTableData.listPrice = element.productWrap.pricebookEntryRec.UnitPrice;
                dataTableData.productDesc = element.productWrap.product.Description;
                dataTableData.productFamily = element.productWrap.product.Family;
                if (element.isParent) {
                    dataTableData.type = 'Parent';
                    this.parentChildProductMap[element.productWrap.product.Id] = element.childProductWrapList;
                } else if (element.ischild) {
                    dataTableData.type = 'Child';
                } else {
                    dataTableData.type = '';
                }
                dataTableData.quantity = null;
                dataTableData.date = null;
                dataTableData.lineDesc = null;
                dataTableAllDataList.push(dataTableData);
            });
            console.log('dataTableAllDataList => ',dataTableAllDataList);
            this.dataTableAllDataList = dataTableAllDataList;
            this.dataTableFilterDataList = dataTableAllDataList;
        }).catch(error => {
            console.log('getData Error ==> ',error);
        }).finally(() => {
            this.isSpinner = false;
        });
    }

    handleSearchChange(event){
        this.searchValue = event.target.value;
        this.filterDataHelper();
    }

    hideShowFilterModal(){
        this.displayFilter = !this.displayFilter;
    }

    handleFilterChange(event){
        this.selectedType = event.target.value;
    }

    restoreFilter(){
        this.displayFilter = false;
        this.selectedType = this.oldFilterValue;
    }

    applyFilter(){
        this.displayFilter = false;
        this.oldFilterValue = this.selectedType;
        this.filterDataHelper();
    }

    filterDataHelper(){
        this.dataTableFilterDataList = this.dataTableAllDataList.filter(data => {
            const includesSearch = this.searchValue ? data.productName.toLowerCase().includes(this.searchValue.toLowerCase()) : true;
            const includesType = this.selectedType == 'All' ? true : this.selectedType == data.type ? true : false;
            return includesSearch && includesType;
        });
    }

    handleRowSelection(event){
        this.selectedProducts = event.detail.selectedRows;
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleNextAction(){
        let selectedProducts = this.selectedProducts;
        let newProductList = [];
        let productIds = new Set();

        selectedProducts.forEach(element => {
            if (element.type == 'Parent') {
                let childList = this.parentChildProductMap[element.productId];
                childList.forEach(ele => {
                    let dataTableData = {};
                    dataTableData.isSelected = false;
                    dataTableData.pricebookEntryLink = '/'+ele.pricebookEntryRec.Id;
                    dataTableData.pricebookEntryLinkId = ele.pricebookEntryRec.Id;
                    dataTableData.productId = ele.product.Id;
                    dataTableData.productName = ele.product.Name;
                    dataTableData.productCode = ele.product.ProductCode;
                    dataTableData.listPrice = ele.pricebookEntryRec.UnitPrice;
                    dataTableData.productDesc = ele.product.Description;
                    dataTableData.productFamily = ele.product.Family;
                    dataTableData.type = 'Child';
                    dataTableData.quantity = 1;
                    dataTableData.date = null;
                    dataTableData.lineDesc = null;
                    if (!productIds.has(dataTableData.productId)) {
                        productIds.add(dataTableData.productId);
                        newProductList.push(dataTableData);
                    }
                });

            }
            if (!productIds.has(element.productId)) {
                productIds.add(element.productId);
                newProductList.push(element);
            }
        });

        this.newProductList = newProductList;
        this.firstPage = false;
        this.secondPage = true;
    }

    handleDataChange(event){
        let selectedLine = event.detail.draftValues[0];
        let newProductList = this.newProductList
        let valueFound = false;

        newProductList.forEach(element => {
            if (element.productId == selectedLine.productId) {
                valueFound = true;
                if (selectedLine.quantity != null) {
                    element.quantity = selectedLine.quantity; 
                } 
                else if (selectedLine.listPrice != null) {
                    element.listPrice = selectedLine.listPrice;
                }
                else if (selectedLine.date != null) {
                    element.date = selectedLine.date;
                } 
                else if (selectedLine.lineDesc != null) {
                    element.lineDesc = selectedLine.lineDesc;
                }
            }
        });
        this.newProductList = newProductList;
    }

    callRowAction(event){
        let collegeDetails = event.detail.row;
        let actionName = event.detail.action.name;

        if (actionName == 'Delete') {
            let newProductList = [];
            this.newProductList.forEach(element => {
                if (element.productId != collegeDetails.productId) {
                    newProductList.push(element);
                }
            });
            this.newProductList = newProductList;
        }
    }

    handleSaveAction(){
        this.isSpinner = true;
        let newProductList = this.newProductList;
        let opportunityLineItemList = [];
        newProductList.forEach(element => {
            let opportunityLineItem = {};
            opportunityLineItem.OpportunityId = this.recordId;
            opportunityLineItem.PricebookEntryId = element.pricebookEntryLinkId;
            opportunityLineItem.Product2Id = element.productId;
            opportunityLineItem.Quantity = element.quantity;
            opportunityLineItem.ProductCode = element.productCode;
            opportunityLineItem.UnitPrice = element.listPrice;
            opportunityLineItem.Description = element.lineDesc;
            //opportunityLineItem.currencyISOcode = 'USD';
            if (element.date) {
                opportunityLineItem.ServiceDate = element.date;
            }
            opportunityLineItemList.push(opportunityLineItem);
        });

        if (opportunityLineItemList.length > 0) {            
            createOpportunityLineItem({oppLineItemList: opportunityLineItemList})
            .then(result => {
                this.dispatchEvent(new RefreshEvent());
                this.displayToastMessage('Success', 'Records saved successfully', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());
            }).catch(error => {
                console.log('createOpportunityLineItem Error ==> ',error);
                this.displayToastMessage('Error', error, 'Error');
            }).finally(() => {
                this.isSpinner = false;
                
            });
        }

    }
    displayToastMessage(title, message, variant) {
        const evt = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(evt);
    }


}