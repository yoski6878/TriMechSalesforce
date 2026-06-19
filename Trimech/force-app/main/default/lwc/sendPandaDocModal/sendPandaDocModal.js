import { LightningElement, api } from 'lwc';
import getTemplates from '@salesforce/apex/sendPandaDocController.getTemplates';
import sendDocument from '@salesforce/apex/sendPandaDocController.sendDocument';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class SendPandaDocModal extends LightningElement {
    @api recordId;
    templates = [];
    templateId;
    isLoading = false;
    documentName = '';

    columns = [{ label: 'Template Name', fieldName: 'label' }];

    connectedCallback() {
        this.loadTemplates();
    }

    async loadTemplates() {
        try {
            this.templates = await getTemplates();
        } catch (e) {
            this.toast('Error', 'Failed to load templates', 'error');
        }
    }

    handleTemplateSelection(event) {
        const row = event.detail.selectedRows?.[0];
        console.log('OUTPUT : ',row);
        this.templateId = row ? row.value : null;
        this.documentName = row ? row.label : null;
    }


    get disableSend() {
        //const { email, firstName, lastName } = this.formData;
        return (
            this.isLoading ||
            !this.templateId
        );
    }

    async handleSend() {
        this.isLoading = true;
        try {
            await sendDocument({
                opportunityId: this.recordId,
                templateId: this.templateId,
                documentName : this.documentName
            });
            this.toast('Success', 'Document sent successfully', 'success');
            this.closeModal();
        } catch (e) {
            this.toast('Error', e?.body?.message || 'Failed to send document', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.closeModal();
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}