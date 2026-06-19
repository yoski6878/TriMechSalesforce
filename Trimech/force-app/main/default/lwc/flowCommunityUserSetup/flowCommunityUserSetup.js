import { LightningElement, api, track } from 'lwc';
import getPicklists from '@salesforce/apex/FlowCommunityUserController.getPicklists';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import upsertUser from '@salesforce/apex/FlowCommunityUserController.upsertUser';
import getUserDetails from '@salesforce/apex/FlowCommunityUserController.getUserDetails';
import {FlowNavigationNextEvent,FlowNavigationBackEvent} from 'lightning/flowSupport';


export default class FlowCommunityUserSetup extends LightningElement {
    @api contactId;
    @api userId = '';
    @api profileId;
    @api profileName;
    @api selectProfileName;
    @track isLoading = false;

    @track firstName;
    @track lastName;
    @track email;
    @track username;
    @track phone;
    @track communityNickname;
    @track alias;
    @track timeZoneSidKey = '';
    @track localeSidKey = '';
    @track emailEncodingKey = '';
    @track languageLocaleKey = '';
    @track isActive = true;
    @track isSaving = false;

    @track errorMessage = '';
    @track timeZoneOptions = [];
    @track localeOptions = [];
    @track emailEncodingOptions = [];
    @track languageOptions = [];

    @api createdUserId;

    connectedCallback() {
        this.isLoading = true;
        // Set defaults for new user
        this.loadUserDetails();
        // Load picklists
        this.loadPicklists();
    }


    loadUserDetails() {
        getUserDetails({ contactId: this.contactId, userId: this.userId })
            .then(result => {
                if (result) {
                    if (result.objectName === 'User') {
                        this.firstName = result.FirstName || '';
                        this.lastName = result.LastName || '';
                        this.email = result.Email || '';
                        this.username = result.Username || '';
                        this.phone = result.Phone || '';
                        this.communityNickname = result.CommunityNickname || '';
                        this.alias = result.Alias || '';
                        this.timeZoneSidKey = result.TimeZoneSidKey || '';
                        this.localeSidKey = result.LocaleSidKey || '';
                        this.emailEncodingKey = result.EmailEncodingKey || '';
                        this.languageLocaleKey = result.LanguageLocaleKey || '';
                        this.isActive = result.IsActive !== false; // default true if null
                    } else if (result.objectName === 'Contact'){
                        this.firstName = result.FirstName || '';
                        this.lastName = result.LastName || '';
                        this.email = result.Email || '';
                        this.phone = result.Phone || '';
                        this.username = result.Email.trim().split('@')[0] + '@trimech.portal';
                        this.communityNickname = `${result.FirstName || ''} ${result.LastName || ''}`.trim();
                        this.alias = ((result.FirstName?.charAt(0) || '') + (result.LastName || '')).substring(0, 8);
                    }
                }
            })
            .catch(error => {
                this.isLoading = false;
                this.errorMessage = 'Failed to load existing User data.';
                console.error('User load error:', error);
            });
    }

    loadPicklists() {
        getPicklists()
            .then(result => {
                this.timeZoneOptions = result.TimeZoneSidKey || [];
                this.localeOptions = result.LocaleSidKey || [];
                this.emailEncodingOptions = result.EmailEncodingKey || [];
                this.languageOptions = result.LanguageLocaleKey || [];
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.errorMessage = 'Failed to load picklist values.';
                console.error(error.stack);
            });
    }


    mapToOptions(values) {
        return values.map(value => ({ label: value, value: value }));
    }


    handleChange(event) {
        this.isLoading = true;
        const field = event.target.dataset.field;
        const value =
            event.target.type === 'checkbox'
                ? event.target.checked
                : event.target.value;

        if (field === 'FirstName') {
            this.firstName = value;
        } else if (field === 'LastName') {
            this.lastName = value;
        } else if (field === 'Email') {
            this.email = value;
        } else if (field === 'Username') {
            this.username = value;
        } else if (field === 'Phone') {
            this.phone = value;
        } else if (field === 'CommunityNickname') {
            this.communityNickname = value;
        } else if (field === 'Alias') {
            this.alias = value;
        } else if (field === 'TimeZoneSidKey') {
            this.timeZoneSidKey = value;
        } else if (field === 'LocaleSidKey') {
            this.localeSidKey = value;
        } else if (field === 'EmailEncodingKey') {
            this.emailEncodingKey = value;
        } else if (field === 'LanguageLocaleKey') {
            this.languageLocaleKey = value;
        }else if (field === 'IsActive') {
            this.isActive = value;
        }
        this.isLoading = false;
    }


    handlePrevious() {
        this.dispatchEvent(new FlowNavigationBackEvent());
    }

    async handleNext() {
        this.isLoading = true;
        const validationResult = await this.validate();
        if (validationResult.isValid) {
            this.dispatchEvent(new FlowNavigationNextEvent());
        }
        this.isLoading = false;
    }

    async validate() {
        this.errorMessage = '';
        this.isSaving = true;

        try {
            // Client-side validation
            const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
                .reduce((validSoFar, inputCmp) => {
                    inputCmp.reportValidity();
                    return validSoFar && inputCmp.checkValidity();
                }, true);

            if (!allValid) {
                this.errorMessage = 'Please complete all required fields.';
                return { isValid: false };
            }

            const userRecord = {
                Id: this.userId || null,
                FirstName: this.firstName,
                LastName: this.lastName,
                Email: this.email,
                Username: this.username,
                Phone: this.phone,
                CommunityNickname: this.communityNickname,
                Alias: this.alias,
                TimeZoneSidKey: this.timeZoneSidKey,
                LocaleSidKey: this.localeSidKey,
                EmailEncodingKey: this.emailEncodingKey,
                LanguageLocaleKey: this.languageLocaleKey,
                ProfileId: this.profileId,
                ContactId: this.contactId,
                IsActive: this.isActive
            };
            console.log({userRecord});

            const result = await upsertUser({ userJson: JSON.stringify(userRecord) });
            this.createdUserId = result;

            // Success toast
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'User was created/updated successfully.',
                variant: 'success'
            }));

            return { isValid: true };
        } catch (error) {
            this.isLoading = false;
            let msg = 'An error occurred while saving the user.';
            if (error.body && error.body.message) {
                msg = error.body.message;
            }
            this.errorMessage = msg;
            return { isValid: false };
        } finally {
            this.isSaving = false;
        }
    }
}