import { LightningElement, api, wire, track  } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import CASE_ACCOUNT_FIELD from '@salesforce/schema/Case.AccountId';
import CASE_CONTACT_FIELD from '@salesforce/schema/Case.ContactId';
import CASE_CREATED_ALIAS_FIELD from '@salesforce/schema/Case.CreatedBy.Alias';

export default class GuestCreatorAlert extends LightningElement {
    @api recordId;
    showMessage = false;
    relatedRecordId;
    relatedObjectType;

    @track caseCreatedAlias ;

    connectedCallback() {
        console.log('recordId');
        console.log(this.recordId);
    }

    @wire(getRecord, { 
        recordId: '$recordId', 
        fields: [CASE_ACCOUNT_FIELD, CASE_CONTACT_FIELD, CASE_CREATED_ALIAS_FIELD]
    })
    wiredCase({ error, data }) {
        if (data) {
            console.log(data);
            const accountId = data.fields.AccountId?.value;
            const contactId = data.fields.ContactId?.value;
            this.caseCreatedAlias = data.fields.CreatedBy.value.fields.Alias.value;
            if (accountId) {
                this.relatedRecordId = accountId;
                this.relatedObjectType = 'Account';
            } 
            if (contactId) {
                this.relatedRecordId = contactId;
                this.relatedObjectType = 'Contact';
            }
        } else if (error) {
            console.error('Error fetching case details:', error);
        }
    }

    @wire(getRecord, {
        recordId: '$relatedRecordId',
        fields: ['$relatedObjectType.CreatedBy.Alias']
    })
    wiredRelatedRecord({ error, data }) {
        if (data) {
            let createdByAlias = null;
            if (this.relatedObjectType === 'Account' && data.fields.CreatedBy) {
                console.log('Inside Acccount');
                createdByAlias = data.fields.CreatedBy.value.fields.Alias.value;
                console.log('OUTPUT : ',createdByAlias);
            } else if (this.relatedObjectType === 'Contact' && data.fields.CreatedBy) {
                console.log('Inside Contact');
                createdByAlias = data.fields.CreatedBy.value.fields.Alias.value;
            }

            if (createdByAlias == 'guest' && this.caseCreatedAlias == 'guest') {
                this.showMessage = true;
            }
        } else if (error) {
            console.error(`Error fetching ${this.relatedObjectType} details:`, error);
        }

    }
}