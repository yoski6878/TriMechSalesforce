import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import recalcForCase from '@salesforce/apex/CaseContactRolesRecalcController.recalcForCase';

export default class RecalcCaseContactRoles extends LightningElement {
    @api recordId;
    isRunning = false;

    handleClick() {
        if (this.isRunning) return;
        this.isRunning = true;

        recalcForCase({ caseId: this.recordId })
            .then(() => {
                this.showToast('Success', 'Recalculated CC contact roles and case sharing.', 'success');
            })
            .catch(error => {
                const message =
                    error && error.body && error.body.message
                        ? error.body.message
                        : 'Unexpected error while recalculating.';
                this.showToast('Error', message, 'error');
            })
            .finally(() => {
                this.isRunning = false;
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