import { LightningElement, track, wire, api } from 'lwc';
import getCaseList from '@salesforce/apex/CaseCustomDatatableController.getCaseList';
import { getPicklistValuesByRecordType, getObjectInfo } from 'lightning/uiObjectInfoApi';
import Case_Object from '@salesforce/schema/Case';

export default class CaseCustomDatatable extends LightningElement {

    @track filterValue = '';
    StatusOptions;
    caseList; 
    @track selectedStatus;

    @track sortedBy = 'CreatedDate';
    @track sortDirection = 'desc';

    caseColumns = [
        { 
            label: 'Case Number', 
            fieldName: 'caseURL', 
            type: 'url', 
            typeAttributes:{
                label : {fieldName : 'CaseNumber'},
                target: '__blank'
            }, sortable: true
        },
        { label: 'Status', fieldName: 'Status', type: 'text' , sortable: true },
        { label: 'Subject', fieldName: 'Subject', type: 'text', sortable: true },
         { 
            label: 'Contact', 
            fieldName: 'contactURL', 
            type: 'url', 
            typeAttributes:{
                label : {fieldName : 'ContactName'},
                target: '__blank'
            } , sortable: true
        },
         { 
            label: 'Account', 
            fieldName: 'accountURL', 
            type: 'url', 
            typeAttributes:{
                label : {fieldName : 'AccountName'},
                target: '__blank'
            } , sortable: true
        },
        { label: 'Priority', fieldName: 'Priority', type: 'text', sortable: true },
        { label: 'CreatedDate', fieldName: 'CreatedDate', type: 'date', sortable: true},
        { label: 'Last Modified Date', fieldName: 'LastModifiedDate', type: 'date', sortable: true}
    ]

    @wire(getPicklistValuesByRecordType, { objectApiName: Case_Object, recordTypeId: '012000000000000AAA' })
    wiredPicklist({ data, error }) {
        if (data) {
            this.StatusOptions = data.picklistFieldValues.Status?.values.map(item => ({
                label: item.label,
                value: item.value
            }));

            // this.softwareVersionOptions = data.picklistFieldValues.Network_Stand_Alone__c.values.map(item =>({label: item.label, value: item.value}));
        } else {
            console.log('Error Fetching Date' + error);
        }
    }

    connectedCallback() {
        this.handleDataLoad();    
    }

    handleInputChange(event){
        this.selectedStatus = event.target.value;
        this.filterValue = this.selectedStatus;
        this.handleDataLoad();
    }

    handleDataLoad(){
        getCaseList({statusFilter : this.filterValue })
        .then(result => {
            this.caseList = result.map(caseRecord=>{
                return {
                    ...caseRecord,
                    caseURL: `/${caseRecord.Id}`,
                    accountURL: `/${caseRecord.AccountId || ''}`,
                    AccountName: `${caseRecord.Account?.Name || ''}`,
                    contactURL: `/${caseRecord.ContactId || ''}`,
                    ContactName: `${caseRecord.Contact?.Name || ''}`
                };
            });
        })
        .catch(error => {
            console.error('Error:', error);
        });
    }

    handleSort(event){

        const{fieldName: sortedBy, sortDirection} = event.detail;

        let sortField;

        if(sortedBy === 'caseURL') sortField = 'CaseNumber';
        else if(sortedBy === 'accountURL') sortField = 'AccountName';
        else if(sortedBy === 'contactURL') sortField = 'ContactName';
        else sortField = sortedBy;
    

        const cloneData = [...this.caseList];
        cloneData.sort((a,b) => {
            let valueA = a[sortField]; 
            let valueB = b[sortField];
            if(typeof valueA === 'string') valueA = valueA.toLowerCase();
            if(typeof valueB === 'string') valueB = valueB.toLowerCase();
            return sortDirection === 'asc' ? (valueA > valueB ? 1: -1): (valueB > valueA ? 1: -1);
        });

        this.caseList = cloneData;
        this.sortDirection = sortDirection;
        this.sortedBy = sortedBy;

    }
}