import { LightningElement, api,wire,track } from 'lwc';
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import duplicateRecords from '@salesforce/apex/DuplicateContactController.duplicateRecords';
import sendemail from '@salesforce/apex/DuplicateContactController.sendemail';
import { CloseActionScreenEvent } from 'lightning/actions';


import IS_SUB_FIELD from "@salesforce/schema/Contact.isSubmitted__c";
import NOTES from "@salesforce/schema/Contact.Notes__c";


const fields = [IS_SUB_FIELD,NOTES];

export default class DuplicateContactQuickAction extends LightningElement {

    _recordId;
    @track dupeaccounts = [];
    originalacts = [];
    activeSections = ['A', 'B'];
    notesValue;
    showSpinner = false;
    isSubmitted= false;

    @api set recordId(value) {
        this._recordId = value;

        console.log('this.recordId',this.recordId);
        this.getDuplicateRecords();

        // do your thing right here with this.recordId / value
    }

    get recordId() {
        return this._recordId;
    }

    get showdupeaccounts(){
        if(this.dupeaccounts && this.dupeaccounts.length)
            return true;

        return false;
    }

    @wire(getRecord, { recordId: "$recordId", fields })
    account({error, data}){
        console.log('loadFields, recordId: ', this.recordId);
        if(error){
            console.log('error', JSON.parse(JSON.stringify(error)));
        }else if(data){
            console.log('data', JSON.parse(JSON.stringify(data)));
            this.isSubmitted = getFieldValue(data, IS_SUB_FIELD);
            this.notesValue = getFieldValue(data, NOTES);
            console.log('this.isSubmitted', this.isSubmitted);
            console.log('notesValue', this.notesValue);
        }
    }

    
   
    getDuplicateRecords(){
        this.showSpinner = true;
        duplicateRecords({ recordId: this.recordId })
		.then(result => {
            console.log('RESULT', result)
			this.dupeaccounts = this.updateAccountData(result['Duplicate']);
            this.originalacts = this.updateAccountData(result['Original']);
            this.showSpinner = false;
        })
		.catch(error => {
            this.showSpinner = false;
			this.error = error;
			this.accounts = undefined;
		})
    }

    handleToggleSection(event){

    }

    updateAccountData(accountList){
        let arr = [];
        for(let i = 0;i<accountList.length;i++){
            let obj = accountList[i];
            obj['link'] = '/'+obj.Id;
            arr.push(obj);
        }
        return arr;
    }

    handleNotesChange(event){
        this.notesValue = event.target.value
    }

    handleSubmit(){
        console.log('this.notesValue',this.notesValue)
        this.showSpinner = true;

        sendemail({ 
            recordId: this.recordId ,
            notes : this.notesValue ,
            original : JSON.stringify(this.originalacts) ,
            duplicate : JSON.stringify(this.dupeaccounts)
        })
		.then(result => {
            console.log('SUCCESS');
            this.showSpinner = false;
            this.dispatchEvent(new CloseActionScreenEvent());
			
        })
		.catch(error => {
            this.showSpinner = false;
			this.error = error;
			
		})
        
    }

    handledelete(event){
        console.log('DATA SET', event.target.dataset.id)
        let arr = [];
        for(let i =0 ;i<this.dupeaccounts.length;i++){
            if(this.dupeaccounts[i].Id == event.target.dataset.id){
               
            }else{
                arr.push(this.dupeaccounts[i]);
            }
        }

        this.dupeaccounts = arr;
    }

    handleValueSelectedOnAccount(event){
        console.log('EVENT', JSON.parse(JSON.stringify( event.detail)));
        let selrecord = event.detail;
        let arr = this.dupeaccounts;
        let obj = new Object();
        obj['Id'] = selrecord.id;
        obj['Name'] = selrecord.mainField;
        obj['BillingStreet'] = selrecord.subField;
        arr.push(obj);
        console.log('ARR', arr)
        this.dupeaccounts = arr;


        /*let arr = [];
        for(let i =0 ;i<this.dupeaccounts.length;i++){
            if(this.dupeaccounts[i].Id == selrecord.oldId){
                console.log('this.dupeaccounts[i]', JSON.parse(JSON.stringify(this.dupeaccounts[i])))
                let obj = new Object();
                obj['Id'] = selrecord.id;
                obj['Name'] = selrecord.mainField;
                obj['BillingStreet'] = selrecord.subField;
                arr.push(obj);
            }else{
                arr.push(this.dupeaccounts[i]);
            }
        }

        this.dupeaccounts = arr;*/
    }
}