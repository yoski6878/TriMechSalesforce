import { LightningElement, api, track } from 'lwc';

export default class FileUploadWithLimit extends LightningElement {
    @api maxFileSize = 10485760; // Default 10MB
    @api accept = '';
    @api recordId;
    @api multiple = false;
    @api disabled = false;
    @api label = 'Upload Files';
    @api title = '';
    @track errorMessage = '';
    @track uploadedFileNames = '';

    // Flow output variables
    @api contentDocumentIds = '';
    @api contentVersionIds = '';

    handleFileChange(event) {
        // Validate file size(s) before upload
        this.errorMessage = '';
        const files = event.detail.files || event.target.files;
        if (files && files.length > 0) {
            for (let file of files) {
                if (file.size > this.maxFileSize) {
                    this.errorMessage = `File size exceeds the limit of ${this.formatBytes(this.maxFileSize)}.`;
                    // Optionally clear the file input (not possible with lightning-file-upload)
                    return;
                }
            }
        }
    }

    handleUploadFinished(event) {
        // event.detail.files is an array of uploaded files
        const uploadedFiles = event.detail.files;
        this.uploadedFileNames = uploadedFiles.map(f => f.name).join(', ');
        // Set Flow output variables
        this.contentDocumentIds = uploadedFiles.map(f => f.documentId).join(',');
        this.contentVersionIds = uploadedFiles.map(f => f.contentVersionId).join(',');
        // Optionally, dispatch event with ContentDocumentIds/ContentVersionIds
        this.dispatchEvent(new CustomEvent('uploadfinished', { detail: uploadedFiles }));
    }

    formatBytes(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }
}