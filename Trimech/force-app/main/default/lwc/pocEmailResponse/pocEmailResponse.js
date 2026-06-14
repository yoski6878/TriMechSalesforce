import { LightningElement,wire } from 'lwc';
import updateCase from '@salesforce/apex/pocEmailResponseController.updateCase';
//import { CurrentPageReference } from 'lightning/navigation';

export default class PocEmailResponse extends LightningElement {

    success = false;
    error = false;

   connectedCallback() {
        try {
            const urlParams = new URLSearchParams(window.location.search);

            const caseId = urlParams.get('caseId');
            const action = urlParams.get('action');

            console.log('CaseId:', caseId);
            console.log('Action:', action);

            if (!caseId || !action) {
                console.warn('Missing caseId or action parameter');
                return;
            }

            updateCase({ caseId: caseId, actionValue: action })
                .then((result) => {
                    console.log('Apex Success:', result);
                    this.success = true;
                })
                .catch((error) => {
                    this.error = true;

                    console.error('Full Error:', error);

                    if (error?.body?.message) {
                        console.error('Error Message:', error.body.message);
                    }

                    if (error?.body?.stackTrace) {
                        console.error('Stack Trace:', error.body.stackTrace);
                    }

                    if (error?.body?.output?.errors) {
                        console.error('Validation Errors:', error.body.output.errors);
                    }
                });

        } catch (err) {
            console.error('Unexpected JS Error:', err);
        }
    }
}