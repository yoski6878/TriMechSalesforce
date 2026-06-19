import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import RECORD_TYPE_ID_FIELD from '@salesforce/schema/Asset.RecordTypeId';
import isCompetitorAsset from '@salesforce/apex/GetRecordTypeInfo.isCompetitorAsset';

export default class PirateBanner extends LightningElement {
    @track isCompetitorAsset = false;
    
    // This will be populated by the target config
    @api recordId;

    @wire(getRecord, { recordId: '$recordId', fields: [RECORD_TYPE_ID_FIELD] })
    wiredRecord({ error, data }) {
        if (data) {
            const recordTypeId = data.fields.RecordTypeId.value;
            // Call Apex method to check if this is a competitor asset
            isCompetitorAsset({ recordTypeId: recordTypeId })
                .then(result => {
                    this.isCompetitorAsset = result;
                })
                .catch(error => {
                    console.error('Error checking competitor asset:', error);
                    this.isCompetitorAsset = false;
                });
        } else if (error) {
            console.error('Error getting record:', error);
            this.isCompetitorAsset = false;
        }
    }
}