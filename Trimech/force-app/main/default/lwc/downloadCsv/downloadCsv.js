import { LightningElement, api } from 'lwc';

export default class DownloadCsv extends LightningElement {
    @api csvString;
    @api filename = 'accounts_in_radius.csv';

    get isCsvValid() {
        return typeof this.csvString === 'string' && this.csvString.length > 0;
    }

    handleDownload() {
        if (!this.isCsvValid) {
            this.showError('CSV data is empty or invalid.');
            return;
        }
        try {
            const downloadElement = document.createElement('a');
            downloadElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(this.csvString);
            downloadElement.target = '_self';
            downloadElement.download = this.filename;
            document.body.appendChild(downloadElement);
            downloadElement.click();
            document.body.removeChild(downloadElement);
        } catch (e) {
            this.showError('Download failed: ' + e.message);
        }
    }

    showError(message) {
        alert(message);
    }
}