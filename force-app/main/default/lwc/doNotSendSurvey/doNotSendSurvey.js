import { LightningElement, api,track } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import CASE_OBJECT from '@salesforce/schema/Case';
import CONTACT_OBJECT from '@salesforce/schema/Contact';
import hasPermission from '@salesforce/apex/DoNotSendSurveyController.hasPermission';


export default class DoNotSendSurvey extends LightningElement {

    @api recordId;

    @track isExecuting = false;

    @api async invoke() {
        if (this.isExecuting) {
            return;
        }
        hasPermission()
            .then((permissionGranted) => {
                if (!permissionGranted) {
                    this.showToast('Access Denied', 'You do not have permission to perform this action.', 'error');
                    return;
                }
                 if (this.recordId.startsWith('500')) {
                    this.updateRecordField(CASE_OBJECT, this.recordId);
                } else if (this.recordId.startsWith('003')) {
                    this.updateRecordField(CONTACT_OBJECT, this.recordId);
                } else {
                    // Handle unsupported record type
                }
            })
            .catch((error) => {
                this.showToast('Error', error.body ? error.body.message : 'Failed to check permission', 'error');
            }); 
    } 

    updateRecordField() {
        const fields = {
            Id: this.recordId,
            Do_Not_Send_Survey__c: true
        };

        updateRecord({ fields })
            .then(() => {
                this.showToast('Success', 'Survey preference updated successfully.', 'success');
            })
            .catch((error) => {
                this.showToast('Error', error.body ? error.body.message : 'Failed to update record', 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}