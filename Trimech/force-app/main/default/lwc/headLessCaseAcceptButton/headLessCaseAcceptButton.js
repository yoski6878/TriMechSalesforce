import { LightningElement, api,track } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import CASE_OBJECT from '@salesforce/schema/Case';
//import hasPermission from '@salesforce/apex/DoNotSendSurveyController.hasPermission';
import USER_ID from '@salesforce/user/Id';


export default class HeadLessDoNotSendSurvey extends LightningElement {

    @api recordId;

    @track isExecuting = false;

    @api async invoke() {
        if (this.isExecuting) {
            return;
        }
        if (this.recordId.startsWith('500')) {
            this.updateRecordField(CASE_OBJECT, this.recordId);
        }
    } 
    updateRecordField() {
        const fields = {
            Id: this.recordId,
            OwnerId: USER_ID
        };

        updateRecord({ fields })
            .then(() => {
                this.showToast('Success', 'Case Ownership Assigned successfully.', 'success');
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