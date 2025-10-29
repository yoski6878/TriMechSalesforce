import { LightningElement, wire, track, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getCaseRecord from '@salesforce/apex/caseSurveyHeaderController.getCaseDetails';
import TrimechLogo from '@salesforce/resourceUrl/TrimechLogo';


export default class CaseSurveyHeader extends LightningElement {

    caseId;
    @track caseRecord = {
        contactName : '',
        accountName : '',
        ownerName : '',
        CaseNumber : '',
        subject : '',
        surveyURL:''
    }

    TMlogo = TrimechLogo;

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        console.log('getPageReference');
        this.caseId = pageRef?.state?.caseId;
        if (this.caseId) {
            console.log('this.caseId');
            console.log(this.caseId);
            this.fetchCaseDetails();
        }
    }

    fetchCaseDetails() {
        getCaseRecord({ caseId: this.caseId })
            .then(result => {
                this.caseRecord = result;
            }).catch(error =>{
                console.log(error.body);
            })
    }

    isInitalRender = true;

    renderedCallback() {
        if (this.isInitalRender) {
            const body = document.querySelector("body");

            const style = document.createElement('style');
            style.innerText = `
                .custom-input .slds-input{
                    padding-bottom: 18px !important;
                    padding-left: 16px !important;
                    border-radius: 0 !important;
                    font-size : 20px;
                }
            `;

            body.appendChild(style);
            this.isInitalRender = false;
        }

    }
}