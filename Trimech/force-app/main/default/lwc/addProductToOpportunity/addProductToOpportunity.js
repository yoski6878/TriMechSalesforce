import { LightningElement, track, api, wire } from 'lwc';
import getProductData from '@salesforce/apex/AddProductToOpportunityController.getProductData';
import createOpportunityLineItem from '@salesforce/apex/AddProductToOpportunityController.createOpportunityLineItem';
import getRelatedChildProductData from '@salesforce/apex/AddProductToOpportunityController.getRelatedChildProductData';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import {CurrentPageReference} from 'lightning/navigation';
import { getPicklistValuesByRecordType , getObjectInfo} from 'lightning/uiObjectInfoApi';
import Product_Object from '@salesforce/schema/Product2';


const TIMEOUT_DURATION = 600;

let timeoutId;

export default class AddProductToOpportunity extends LightningElement {

    @api recordId;
    @api c__recordId;
    @track isSpinner = false;
    @track productDataList = [];
    @track parentChildProductMap = {};
    @track dataTableFullDataList = [];
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
    @track lastPricebookEntryId = '';
    @track initialLoad = true;
    @track currentPage = 1;
    @track totalPages = 1;
    @track recordsToDsiaply = 50;
    @track totalRecords;
    @track hasMoreRecords = true;

    @track dataTablePaginationList = [];

    @track filterWrapper = {};
    @track tempFilterWrapper ={};


    licenceTypeOptions=[];
    clientTypeOptions = [];
    networkOptions = [];
    eliteEssentialOptions = [];
    productClassOptions = [];

    recordtypeId = '';


    @wire(getPicklistValuesByRecordType, {objectApiName: Product_Object,recordTypeId: '012000000000000AAA'})
    wiredPicklist({data, error}){
        if(data){
            this.licenseTypeOptions = data.picklistFieldValues.License_Type__c.values.map(item =>({label: item.label, value: item.value}));
            this.clientTypeOptions = data.picklistFieldValues.Client_Type__c.values.map(item =>({label: item.label, value: item.value}));
            this.networkOptions = data.picklistFieldValues.Network_Stand_Alone__c.values.map(item =>({label: item.label, value: item.value}));
            this.eliteEssentialOptions = data.picklistFieldValues.Elite_Essential__c.values.map(item =>({label: item.label, value: item.value}));
            this.productClassOptions = data.picklistFieldValues.Class__c.values.map(item =>({label: item.label, value: item.value}));
            this.businessUnitOptions = data.picklistFieldValues.Business_Unit__c.values.map(item =>({label: item.label, value: item.value}));
        }else{
            console.log('Error Fetching Date' + error);
        }
    }


    get isFirstPage (){
        return this.currentPage == 1;
    }

    get isLastPage (){
        return this.currentPage == this.totalPages;
    }

    get currentRecordListSize(){
        return this.dataTableAllDataList.length
    }

    @track listViewButton = 'false';

    @wire(CurrentPageReference)
    getStateParameters(CurrentPageReference){
        if(CurrentPageReference){
            this.c__recordId = CurrentPageReference.state?.c__recordId;   
            this.listViewButton = CurrentPageReference.state?.c__listView;   
        }
    }

    recordListOptions = 
    [
        {label : 50 , value : 50},
        {label : 100 , value : 100},
        {label : 200 , value : 200}
    ]

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
            label: 'License Type', 
            fieldName: 'licenseType', 
            type: 'String'
        },
        { 
            label: 'Product Type', 
            fieldName: 'type', 
            type: 'String'
        },
        { 
            label: 'Client Type', 
            fieldName: 'clientType', 
            type: 'String'
        },
        { 
            label: 'Network/Stand Alone', 
            fieldName: 'network', 
            type: 'String'
        },
        { 
            label: 'Elite/Essential', 
            fieldName: 'EliteEssential', 
            type: 'String'
        },
        { 
            label: 'Product Class', 
            fieldName: 'productClass', 
            type: 'String'
        }
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
        // { 
        //     label: 'Date', 
        //     fieldName: 'date', 
        //     type: 'date-local',
        //     editable: true 
        // },
        { 
            label: 'Line Description', 
            fieldName: 'lineDesc', 
            type: 'String',
            editable: true 
        },
        // { 
        //     label: 'Product Type', 
        //     fieldName: 'type', 
        //     type: 'String'
        // },
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
        return this.selectedRows.length > 0 ? false : true;
    }


    connectedCallback() { 

        this.filterWrapper.productType = 'All';

        this.isSpinner = true;
        setTimeout(() => {
            this.getDataHelper();
        }, 1000);
    }

    isRendered = false;

    renderedCallback(){

        if (this.isRendered) return;

        const style = document.createElement('style');
        style.innerHTML = `.uiModal--horizontalForm .modal-container{
            width: 100% !important;
            max-width: 90% !important;
            min-width: 480px !important;
            max-height: 100% !important;
            min-height: 480px !important;
        }`;

        this.template.querySelector('lightning-quick-action-panel').appendChild(style);
        this.isRendered = true;

    }

    getDataHelper(){

        this.isSpinner = true;

        var oppRecordId;

        if(this.recordId){
            oppRecordId = this.recordId
        }else{
            oppRecordId = this.c__recordId;
        }
        
        getProductData({opportunityId: oppRecordId , lastPricebookEntryId: this.lastPricebookEntryId, isInitialLoad : this.initialLoad , appliedFilters : JSON.parse(JSON.stringify(this.filterWrapper))  })
        .then(result => {
            this.productDataList = result;
            console.log('result');
            console.log(result);
            let dataTableAllDataList = [];
            result.forEach(element => {
                let dataTableData = {};
                //dataTableData.isSelected = false;
                dataTableData.pricebookEntryLink = '/'+element.productWrap.pricebookEntryRec.Id;
                dataTableData.pricebookEntryLinkId = element.productWrap.pricebookEntryRec.Id;
                dataTableData.productId = element.productWrap.product.Id;
                dataTableData.productName = element.productWrap.product.Name;
                dataTableData.productCode = element.productWrap.product.ProductCode;
                dataTableData.listPrice = element.productWrap.pricebookEntryRec.UnitPrice;
                dataTableData.productDesc = element.productWrap.product.Description;
                dataTableData.licenseType = element.productWrap.product.License_Type__c;
                dataTableData.clientType = element.productWrap.product.Client_Type__c;
                dataTableData.network = element.productWrap.product.Network_Stand_Alone__c;
                dataTableData.productClass = element.productWrap.product.Class__c;
                dataTableData.EliteEssential = element.productWrap.product.Elite_Essential__c;
                this.lastPricebookEntryId = element.productWrap.pricebookEntryRec.Id;

                if(this.initialLoad){
                    this.totalRecords = element.recordCount;
                }



                if (element.isParent) {
                    dataTableData.type = 'Parent';
                    this.parentChildProductMap[element.productWrap.product.Id] = element.childProductWrapList;
                } else if (element.ischild) {
                    dataTableData.type = 'Child';
                } else {
                    dataTableData.type = '';
                }
                dataTableData.quantity = element.productWrap.product.Minimum_Quantity__c ? element.productWrap.product.Minimum_Quantity__c : 1;
                dataTableData.date = null;
                dataTableData.lineDesc = null;
                
                dataTableAllDataList.push(dataTableData);
            });

            if(!result || result.length == 0){
                this.totalRecords = 0;
            }

            if(this.initialLoad){
                this.dataTableAllDataList = [];
            }
            this.dataTableAllDataList.push(...dataTableAllDataList);
            if(this.initialLoad){
                this.hasMoreRecords = parseInt(this.totalRecords) > 1000;
            }else{
                this.hasMoreRecords = dataTableAllDataList.length > 300;
            }
            this.totalPages = Math.ceil( this.totalRecords / this.recordsToDsiaply) != 0? Math.ceil( this.totalRecords / this.recordsToDsiaply) : 1;
            this.initialLoad = false;
            this.setTableData();
        }).catch(error => {
            console.log('getData Error ==> ',error);
        }).finally(() => {
            this.isSpinner = false;
        });
    }

    handleShowRecords(event){
        this.recordsToDsiaply = parseInt(event.target.value);
        this.totalPages = Math.ceil( this.totalRecords / this.recordsToDsiaply) !=0? Math.ceil( this.totalRecords / this.recordsToDsiaply) : 1;
        this.currentPage = 1;
        this.setTableData();
    }
    
    setTableData() {
        this.dataTablePaginationList = [];
        this.dataTableFilterDataList = [];

        var splitStart = 0;
        if(this.currentPage == 1){
            splitStart = 0;
        }else{
            splitStart = this.recordsToDsiaply * (this.currentPage - 1);
        }

        if (this.filterWrapper.productType != 'All' && this.filterWrapper.productType != '' && this.filterWrapper.productType ) {
            console.log('this.dataTableAllDataList.length');
            console.log(this.dataTableAllDataList.length);

            this.dataTableFilterDataList = this.dataTableAllDataList.filter(element => {
                if (element.type == this.filterWrapper.productType) {
                    return true;
                } else {
                    return false;
                 }
            });
            this.totalPages = Math.ceil( this.dataTableFilterDataList.length / this.recordsToDsiaply) != 0 ? Math.ceil( this.dataTableFilterDataList.length / this.recordsToDsiaply) : 1;
            this.dataTablePaginationList = this.dataTableFilterDataList.slice(splitStart, (splitStart+this.recordsToDsiaply));
        }else{
            this.dataTablePaginationList = this.dataTableAllDataList.slice(splitStart, (splitStart+this.recordsToDsiaply));
        }   

        var lastRecordNumber =  this.recordsToDsiaply*this.currentPage;
        if(this.totalRecords > lastRecordNumber && lastRecordNumber > this.currentRecordListSize && this.hasMoreRecords){
            this.loadMoreData()
        }

        this.template.querySelector('[data-id="datatable"]').selectedRows = this.selectedRows;

    }

    handleSearchChange(event){
        this.filterWrapper[event.target.name] = event.target.value;
        this.currentPage = 1;
        this.initialLoad = true;
        this.lastPricebookEntryId = '';

        window.clearTimeout(timeoutId);

        timeoutId = setTimeout(() => {
            this.getDataHelper();
        }, TIMEOUT_DURATION);
    }

    hideShowFilterModal(){
        this.displayFilter = !this.displayFilter;
    }

    handleChildValueUpdates(event){
        const { filterName, filterValue } = event.detail;
        this.tempFilterWrapper = { ...this.tempFilterWrapper, [filterName]: filterValue };
    }


    handleFilterChange(event){
        var filterName = event.target.name;
        var filterValue = event.target.value;
        console.log('filterValue');
        console.log(filterValue);
        this.tempFilterWrapper[filterName] = filterValue;
    }

    restoreFilter(){
        this.displayFilter = false;
        this.tempFilterWrapper = JSON.parse(JSON.stringify(this.filterWrapper));
    }

    handleResetFilters(){
        this.displayFilter = false;
        this.initialLoad = true;
        this.lastPricebookEntryId = '';
        this.tempFilterWrapper = {};
        this.tempFilterWrapper.productType = 'All';
        if(this.filterWrapper.searchValue != '' && this.filterWrapper.searchValue != null){
            this.tempFilterWrapper.searchValue = this.filterWrapper.searchValue;
        }
        this.filterWrapper = JSON.parse(JSON.stringify(this.tempFilterWrapper));
        setTimeout(() => {
            this.getDataHelper();
        }, 1500);
    }


    applyFilter(){
        this.displayFilter = false;
        this.initialLoad = true;
        this.lastPricebookEntryId = '';
        this.currentPage = 1;

        if(this.filterWrapper.searchValue != '' && this.filterWrapper.searchValue != null){
            this.tempFilterWrapper.searchValue = this.filterWrapper.searchValue;
        }


        this.filterWrapper = JSON.parse(JSON.stringify(this.tempFilterWrapper));
        setTimeout(() => {
            this.getDataHelper();
        }, 800);
    }

    @track selectedRows=[];

    handleRowSelection(event) {
        let updatedItemsSet = new Set();
        // List of selected items we maintain.
        let selectedItemsSet = new Set(this.selectedRows);
        // List of items currently loaded for the current view.
        let loadedItemsSet = new Set();
        this.dataTablePaginationList.map((ele) => {
            loadedItemsSet.add(ele.pricebookEntryLinkId);
        });
        if (event.detail.selectedRows) {
            event.detail.selectedRows.map((ele) => {
                updatedItemsSet.add(ele.pricebookEntryLinkId);
            });
            // Add any new items to the selectedRows list
            updatedItemsSet.forEach((id) => {
                if (!selectedItemsSet.has(id)) {
                    selectedItemsSet.add(id);
                }
            });
        }
        loadedItemsSet.forEach((id) => {
            if (selectedItemsSet.has(id) && !updatedItemsSet.has(id)) {
                // Remove any items that were unselected.
                selectedItemsSet.delete(id);
            }
        });
        this.selectedRows = [...selectedItemsSet];
        // Map the selected items to the UI list.

        console.log('this.selectedRows');
        console.log(this.selectedRows);
        console.log(JSON.stringify(this.selectedRows));

        // add logic to add and remove the selectedRow list into selectedProduct

        let preservedProducts = this.selectedProducts.filter(product => 
            this.selectedRows.includes(product.pricebookEntryLinkId) &&
            !this.dataTableAllDataList.some(data => data.pricebookEntryLinkId === product.pricebookEntryLinkId)
        );

        let newSelectedProducts = this.selectedRows.map((id) => {
            return this.dataTableAllDataList.find((ele) => ele.pricebookEntryLinkId === id);
        }).filter(product => product);

        this.selectedProducts = [...preservedProducts, ...newSelectedProducts];

        console.log('this.selectedProducts:', JSON.stringify(this.selectedProducts));

        
    }



    loadMoreData(){
        console.log('Load More Data');
        this.initialLoad = false;
        this.getDataHelper();
    }

    closeModal() {

            
        var oppRecordId;

        if(this.recordId){
            oppRecordId = this.recordId
        }else{
            oppRecordId = this.c__recordId;
        }


        if(this.listViewButton == 'true'){
            let url = window.location.origin + '/lightning/r/Opportunity/'+oppRecordId+'/related/OpportunityLineItems/view';
            window.location.replace(url);
            this.dispatchEvent(new RefreshEvent());
        }else{
            this.dispatchEvent(new CloseActionScreenEvent());
        }
        
    }

    handleNextAction(){
        try{

            this.selectedRows.forEach((id) => {
                if (!this.selectedProducts.some(product => product.pricebookEntryLinkId === id)) {
                    const product = this.dataTableAllDataList.find(ele => ele.pricebookEntryLinkId === id);
                    if (product) {
                        this.selectedProducts.push(product);
                    }
                }
            });

            let selectedProducts = JSON.parse(JSON.stringify( this.selectedProducts));
            console.log('selectedProducts');
            console.log(selectedProducts);
            let newProductListTemp = [];
            let productIds =[];

            selectedProducts.forEach(element => {
                if (!productIds.includes(element.productId)) {
                    //element.quantity = 1;
                    productIds.push(element.productId);
                    newProductListTemp.push(element);
                }
            });

            console.log('productIds');
            console.log(productIds);

            var oppId;
            if(this.recordId){
                oppId = this.recordId
            }else{
                oppId = this.c__recordId;
            }


            if(productIds.length > 0){
                getRelatedChildProductData({productIds : productIds , opportunityId: oppId})
                .then(result => {
                    console.log('result --> ' +result );
                    result.forEach(ele => {
                        console.log(ele);
                        let dataTableData = {};
                        dataTableData.isSelected = false;
                        dataTableData.pricebookEntryLink = '/'+ele.pricebookEntryRec.Id;
                        dataTableData.pricebookEntryLinkId = ele.pricebookEntryRec.Id;
                        dataTableData.productId = ele.product.Id;
                        dataTableData.productName = ele.product.Name;
                        dataTableData.productCode = ele.product.ProductCode;
                        dataTableData.listPrice = ele.pricebookEntryRec.UnitPrice;
                        dataTableData.productDesc = ele.product.Description;
                        dataTableData.type = 'Child';
                        dataTableData.quantity = ele.product.Minimum_Quantity__c? ele.product.Minimum_Quantity__c : 1 ;
                        dataTableData.date = null;
                        dataTableData.lineDesc = null;
                        if (!productIds.includes(dataTableData.productId)) {

                            newProductListTemp.push(dataTableData);
                            productIds.push(dataTableData.productId);
                        }
                    });

                    this.newProductList = newProductListTemp;
                    this.firstPage = false;
                    this.secondPage = true;

                }).catch(error => {
                    console.log('Error in getRelatedChildDate' + error);
                    console.log(JSON.stringify(error));
                })
            }
            else{

                 this.newProductList = newProductListTemp;
                this.firstPage = false;
                this.secondPage = true;

            }

           
        }catch(error){
            console.log('Error in handleNextAction' + {error});
        }
    }

    handleDataChange(event){
        let selectedLine = event.detail.draftValues[0];
        let newProductList = this.newProductList
        let valueFound = false;

        console.log('selectedLine');
        console.log({selectedLine});

        newProductList.forEach(element => {
            if (element.pricebookEntryLinkId == selectedLine.pricebookEntryLinkId) {
                valueFound = true;
                if (selectedLine.quantity != null) {
                    console.log('Inside quantity');
                    element.quantity = selectedLine.quantity; 
                    console.log('element.quantity -->' + element.quantity);
                    console.log('selectedLine.quantity -->'+selectedLine.quantity);
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
        let rowId = event.detail.row.pricebookEntryLinkId;
        let actionName = event.detail.action.name;

        console.log('rowId --> '+ rowId);
        console.log('this.selectedRows');
        console.log(this.selectedRows);
        console.log('this.collegeDetails');
        console.log(this.collegeDetails);

        this.selectedRows = this.selectedRows.filter(record => record != rowId);

        if (actionName == 'Delete') {
            let newProductList = [];
            this.newProductList.forEach(element => {
                if (element.productId != collegeDetails.productId) {
                    newProductList.push(element);
                }
            });
            this.newProductList = newProductList;
            this.selectedProducts = this.selectedProducts.filter(record => record.pricebookEntryLinkId != rowId);
        }
    }

    handleSaveAction(){
        this.isSpinner = true;
        let newProductList = this.newProductList;
        let opportunityLineItemList = [];
    
        var oppRecordId;

        if(this.recordId){
            oppRecordId = this.recordId
        }else{
            oppRecordId = this.c__recordId;
        }

        newProductList.forEach(element => {
            let opportunityLineItem = {};
            opportunityLineItem.OpportunityId = oppRecordId;
            opportunityLineItem.PricebookEntryId = element.pricebookEntryLinkId;
            opportunityLineItem.Product2Id = element.productId;
            opportunityLineItem.Quantity = element.quantity;
            console.log('element.quantity --> ' + element.quantity);
            console.log('opportunityLineItem.Quantity --> ' + opportunityLineItem.Quantity);
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
                let url = window.location.origin + '/lightning/r/Opportunity/'+oppRecordId+'/related/OpportunityLineItems/view';
                window.location.replace(url);

                this.dispatchEvent(new RefreshEvent());
                this.displayToastMessage('Success', 'Records saved successfully', 'success');
                
                this.dispatchEvent(new CloseActionScreenEvent());
            }).catch(error => {
                console.log('createOpportunityLineItem Error ==> ',error);
                console.log(JSON.stringify(error));
                this.handleError(error);
                //this.displayToastMessage('Error', error.body.pageErrors.message, 'Error');
            }).finally(() => {
                this.isSpinner = false;
                
            });
        }

    }

    handleError(error) {
        let messages = [];

        // Extract page-level errors
        if (error?.body?.pageErrors?.length) {
            error.body.pageErrors.forEach(err => {
                messages.push(err.message);
            });
        }

        // Extract field-level errors
        if (error?.body?.fieldErrors) {
            Object.values(error.body.fieldErrors).forEach(fieldErrs => {
                fieldErrs.forEach(err => {
                    messages.push(err.message);
                });
            });
        }

        // Extract duplicate result errors
        if (error?.body?.duplicateResults?.length) {
            error.body.duplicateResults.forEach(err => {
                messages.push(err.message);
            });
        }

        // Fallback to general error
        if (messages.length === 0 && error?.body?.message) {
            messages.push(error.body.message);
        }

        // ✅ Iterate over messages and show one toast per error
        messages.forEach(message => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error',
                mode: 'sticky' // stays until user closes it
            }));
        });
    }
    
    handlePagination(event){
        var action = event.target.name;
        if (action == 'previous') {
            this.currentPage--;
        } else if (action == 'next') {
            this.currentPage++;
        }
        
        this.setTableData();
    }

    displayToastMessage(title, message, variant) {
        const evt = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(evt);
    }

    handlePreviousAction(){
        this.firstPage  = true;
        this.secondPage = false;
    }

}