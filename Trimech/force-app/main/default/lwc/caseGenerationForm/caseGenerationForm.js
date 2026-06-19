import { LightningElement, track, wire } from 'lwc';
import generateCase from '@salesforce/apex/CaseGenerationFormController.generateCase';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValuesByRecordType, getObjectInfo } from 'lightning/uiObjectInfoApi';
import getCustomPickListValues from '@salesforce/apex/CaseGenerationFormController.getCustomPickListValues';
import Case_Object from '@salesforce/schema/Case';
import { loadScript } from 'lightning/platformResourceLoader';

export default class CaseGenerationForm extends LightningElement {

    @track caseObj = {
        FirstName: '',
        LastName: '',
        CompanyName: '',
        phoneNumber: '',
        email: '',
        productName: '',
        softwareVersion: '',
        serialNumber: '',
        subject: '',
        typeValue: '',
        priority: '',
        description: '',
        contentDocumentId: '',
        encryptionToken: '',
        contentVersionId: ''
    }

    @track isSubmitted = false;
    @track pendingSubmit = false;

    disableButton = true;

    @track showUrgentModal = false;

    acceptedFormats = ['.zip', '.pdf', '.docx', '.7z', '.jpg', '.png', '.jpeg'];

    @track encryptedToken = '';
    @track filePill = '';
    @track fileUploadDisabled = false;

    @track isLoading = false;

    productOptions = [];

    priorityOptions = [];
    typeOptions = [];
    baseTypeOptions =[];

    softwareVersionOptions = [];

    hardwareOptions = [
        { label: 'Printer Installation', value: 'Printer Installation' },
        { label: 'Printer Preventative Maintenance', value: 'Printer Preventative Maintenance' },
        { label: 'Printer Repair', value: 'Printer Repair' }
    ];

    cam = [
        { label: 'Post Modifications - EXTERNAL', value: 'Post Modifications - EXTERNAL' },
        { label: 'Post Modifications - INTERNAL', value: 'Post Modifications - INTERNAL' },
        { label: 'Post Request', value: 'Post Request' },
    ]

    pmd = [
        { label: 'PDM Health Check', value: 'PDM Health Check' }
    ]

    hiddenPicklistMap = new Map([
        ['3D Printers', this.hardwareOptions],
        ['Printer Installation', this.hardwareOptions],
        ['Printer Preventative Maintenance', this.hardwareOptions],
        ['Printer Repair', this.hardwareOptions],
        ['SOLIDWORKS CAM', this.cam],
        ['SolidCAM', this.cam],
        ['SWOOD', this.cam],
        ['3DEXPERIENCE NC Shop Floor Programmer', this.cam],
        ['SOLIDWORKS PDM Professional', this.pmd],
        ['SOLIDWORKS PDM Standard', this.pmd]
    ]);


    @track file;
    @wire(getPicklistValuesByRecordType, { objectApiName: Case_Object, recordTypeId: '012000000000000AAA' })
    wiredPicklist({ data, error }) {
        if (data) {
            this.priorityOptions = data.picklistFieldValues.Priority?.values.filter(item => item.value != 'Undefined').map(item => ({
                label: item.label,
                value: item.value
            }));

            const allHiddenValues = Array.from((this.hiddenPicklistMap).values()).flat().map(item => item.value);
            this.baseTypeOptions = data.picklistFieldValues.Type?.values
            .filter(item =>
                item.value !== 'Undefined' &&
                item.value !== 'Handed Off to Another Team' &&
                item.value !== 'Student' &&
                item.value !== 'Client Self-Resolved' &&
                !allHiddenValues.includes(item.value)
            )
            .map(item => ({
                label: item.label,
                value: item.value
            }));

            this.typeOptions = [...this.baseTypeOptions];

            // this.softwareVersionOptions = data.picklistFieldValues.Network_Stand_Alone__c.values.map(item =>({label: item.label, value: item.value}));
        } else {
            console.log('Error Fetching Date' + error);
        }
    }

    handleProductChange() {
        this.typeOptions = [...this.baseTypeOptions];
        const selectedProduct = this.caseObj.productName;
        this.caseObj.typeValue = '';
        if (this.hiddenPicklistMap.has(selectedProduct)) {
            const extraOptions = this.hiddenPicklistMap.get(selectedProduct);

            this.typeOptions = [
                ...extraOptions,
                ...this.typeOptions
            ];
        }
    }


    handleButtonStatus(event) {
        console.log('handleButtonStatus');
        console.log('event.detail -->' + event.detail);
        if (event.detail == 'Enable') {
            this.disableButton = false;
        } else if (event.detail == 'Disable') {
            this.disableButton = true;
        }
    }

    loadPicklistValues() {
        getCustomPickListValues({
            objectApiName: 'Case',
            fieldApiName: 'Issue__c'
        })
            .then(result => {
                this.productOptions = result.map(item => ({
                    label: item.label,
                    value: item.value
                }));
                this.error = undefined;
            })
            .catch(error => {
                console.log('Error fetching picklist values: ' + error.body.message);
            });

        getCustomPickListValues({
            objectApiName: 'Case',
            fieldApiName: 'Software_Version__c'
        })
            .then(result => {
                this.softwareVersionOptions = result.map(item => ({
                    label: item.label,
                    value: item.value
                }));
                this.error = undefined;
            })
            .catch(error => {
                console.log('Error fetching picklist values: ' + error.body.message);
            });

    }

    handleChange(event) {
        const name = event.target.name;
        const value = event.target.value;
        this.caseObj[name] = value;
        if (name === 'productName' && this.hiddenPicklistMap.has(value)) {
            this.handleProductChange();
        }else if (name === 'productName'){
            this.typeOptions = this.baseTypeOptions;
        }
    }

    @track isInitalRender = true;

    scriptUrl = false;
    scriptUrl = 'https://trimech.com/assets/pardot/scripts/iframecode.js';


    renderedCallback() {
        if (this.isInitalRender) {
            const body = document.querySelector("body");

            const style = document.createElement('style');
            style.innerText = `
                .custom-input .slds-input{
                    padding-top:16px !important;
                    padding-bottom: 16px !important;
                    border-radius: 0 !important;
                }

                .custom-input .slds-textarea{
                    border-radius: 0 !important;
                    padding-top:16px !important;
                    padding-bottom: 16px !important;
                }

                .custom-input .fix-slds-input_faux{
                    line-height: max(3.875rem, calc(1.2em - 2px)) !important;
                }

                .custom-input. slds-input_faux{
                    border-radius: 0 !important;
                }
            `;

            body.appendChild(style);
            this.isInitalRender = false;
        }

        // if (this.scriptLoaded) {
        //     return; // Prevent reloading the script
        // }
        // this.scriptLoaded = true;
        // loadScript(this, this.scriptUrl)
        //     .then(() => {
        //         console.log('Script loaded successfully!');
        //     })
        //     .catch((error) => {
        //         console.error('Error loading script:', error);
        //     });
    }

    connectedCallback() {
        this.loadPicklistValues();
        this.encryptedToken = this.generateRandomToken();

        this.scriptLoaded = true;
        loadScript(this, this.scriptUrl)
            .then(() => {
                console.log('Script loaded successfully!');
            })
            .catch((error) => {
                console.error('Error loading script:', error);
            });

    }

    handleSubmit(event) {
        try {
            this.isLoading = true;

            const allValid = [...this.template.querySelectorAll('lightning-input, lightning-textarea, lightning-combobox')]
                .reduce((validSoFar, inputCmp) => {
                    inputCmp.reportValidity();
                    return validSoFar && inputCmp.checkValidity();
                }, true);

            if (!allValid) {
                this.isLoading = false;
                this.showToast('Error', 'Please fill all the required fields', 'error');
                return;
            }

            if (this.caseObj.priority === 'Urgent' && !this.pendingSubmit) {
                this.isLoading = false;
                this.showUrgentModal = true;
                return;
            }

            this.showUrgentModal = false;
            this.pendingSubmit = false;

            generateCase({ caseRecord: JSON.stringify(this.caseObj) })
                .then(result => {
                    if (result) {
                        this.showToast('Success', 'Case created successfully', 'success');
                        this.caseObj = {
                            FirstName: '',
                            LastName: '',
                            CompanyName: '',
                            phoneNumber: '',
                            email: '',
                            productName: '',
                            softwareVersion: '',
                            serialNumber: '',
                            subject: '',
                            typeValue:'',
                            priority: '',
                            description: '',
                            contentDocumentId: '',
                            encryptionToken: '',
                            contentVersionId: ''
                        };
                        this.fileUploadDisabled = false;
                        this.file = null;
                        this.isLoading = false;
                        this.encryptedToken = this.generateRandomToken();
                        this.isSubmitted = true;
                    }
                })
                .catch(error => {
                    this.isLoading = false;
                    console.log('error', error.body.message);
                    this.showToast('Error', 'Something Went Wrong', 'error');
                });

        } catch (error) {
            this.isLoading = false;
            console.log('Error in HandleSubmit ---->', error.message);
        }
    }

    confirmUrgentSubmit() {
        this.pendingSubmit = true;
        this.handleSubmit(); 
    }

    cancelUrgentSubmit() {
        this.showUrgentModal = false;
        this.isLoading = false;
    }


    handleUploadedFile(event) {
        console.log('handleUploadedFile');
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.file = uploadedFiles[0];
            this.caseObj.contentVersionId = JSON.parse(JSON.stringify(this.file)).contentVersionId;
            this.caseObj.encryptionToken = this.encryptedToken;
            this.fileUploadDisabled = true;
            console.log(this.file);
        }
    }

    showToast(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(toastEvent);
    }

    handleRemove(event) {
        this.caseObj.contentDocumentId = '';
        this.caseObj.contentVersionId = '';
        this.fileUploadDisabled = false;
        this.file = null;
        this.encryptedToken = this.generateRandomToken();
    }

    generateRandomToken() {
        const token = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
        return token;
    }

}