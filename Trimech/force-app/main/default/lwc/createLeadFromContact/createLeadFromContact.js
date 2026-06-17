import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getInitData from '@salesforce/apex/CreateLeadFromContactController.getInitData';
import getTeamRoleOptions from '@salesforce/apex/CreateLeadFromContactController.getTeamRoleOptions';
import addTeamAndContactRole from '@salesforce/apex/CreateLeadFromContactController.addTeamAndContactRole';
import getDefaultTeamMembers from '@salesforce/apex/CreateLeadFromContactController.getDefaultTeamMembers';

let rowKey = 0;

export default class CreateLeadFromContact extends NavigationMixin(LightningElement) {
    @api recordId; // Contact Id or Account Id (provided by quick action / record page)

    @track teamRows = [];
    accountId;
    defaultOppName;
    leadRecordTypeId;
    hasAccount = false;
    isAccount = false;
    selectedContactId;
    softwareProductGroupId;
    errorMessage;
    roleOptions = [];
    isSaving = false;
    pendingTeamMembers = [];
    // Plain (non-reactive) maps keyed by row key. The picker/combobox change events are
    // the reliable source of the selection — lightning-record-picker.value does NOT
    // reflect the user's pick when read back from the DOM.
    userIdByKey = {};
    roleByKey = {};
    showDefaultTeam = false;
    defaultTeamMembers = [];
    loadingDefaultTeam = false;

    @wire(getInitData, { recordId: '$recordId' })
    wiredInit({ data, error }) {
        if (data) {
            this.accountId = data.accountId;
            this.defaultOppName = data.defaultOppName;
            this.leadRecordTypeId = data.leadRecordTypeId;
            this.hasAccount = data.hasAccount;
            this.isAccount = data.isAccount;
            this.softwareProductGroupId = data.softwareProductGroupId;
            if (!data.hasAccount) {
                this.errorMessage =
                    'There is no Account associated with this Contact. Please set the Account before creating the lead.';
            }
        } else if (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    // Active TeamMemberRole picklist values, returned directly by Apex (avoids the
    // unstable getObjectInfo/getPicklistValues record-type resolution for this object).
    @wire(getTeamRoleOptions)
    wiredRoles({ data }) {
        if (data) {
            this.roleOptions = data;
        }
    }

    get oppFieldNames() {
        return [
            'Name',
            'CloseDate',
            'StageName',
            'LeadSource',
            'Type',
            'Product_Group__c',
            'Opportunity_Type__c',
            'End_User_Department__c',
            'Lyme_Quote__c',
            'Value_Upgrade__c'
        ];
    }

    get hasTeamRows() {
        return this.teamRows.length > 0;
    }

    // Default Expected Close Date to today, mirroring the flow ($Flow.CurrentDate).
    get today() {
        return new Date().toISOString().slice(0, 10);
    }

    // Restrict the user picker to active internal (Standard) users; portal/integration
    // user types cannot be Opportunity team members (OP_WITH_INVALID_USER_TYPE_EXCEPTION).
    get userFilter() {
        return {
            criteria: [
                { fieldPath: 'IsActive', operator: 'eq', value: true },
                { fieldPath: 'UserType', operator: 'eq', value: 'Standard' }
            ],
            filterLogic: '1 AND 2'
        };
    }

    // When launched from an Account, the primary-contact picker is limited to that account.
    get contactFilter() {
        return {
            criteria: [{ fieldPath: 'AccountId', operator: 'eq', value: this.accountId }],
            filterLogic: '1'
        };
    }

    get disableSave() {
        return this.isSaving || !this.hasAccount;
    }

    handlePrimaryContactChange(event) {
        this.selectedContactId = event.detail ? event.detail.recordId : null;
        if (event.target && event.target.reportValidity) {
            event.target.reportValidity();
        }
    }

    addTeamRow() {
        rowKey += 1;
        this.teamRows = [...this.teamRows, { key: `row-${rowKey}`, userId: null, role: null }];
    }

    removeTeamRow(event) {
        const { key } = event.currentTarget.dataset;
        this.teamRows = this.teamRows.filter((r) => r.key !== key);
        delete this.userIdByKey[key];
        delete this.roleByKey[key];
    }

    rowKeyOf(event) {
        return (
            event.currentTarget?.dataset?.key ||
            event.target?.dataset?.key
        );
    }

    handleUserChange(event) {
        const key = this.rowKeyOf(event);
        const userId =
            event.detail?.recordId ||
            event.detail?.value ||
            event.currentTarget?.value ||
            event.target?.value ||
            null;
        if (key) {
            this.userIdByKey[key] = userId;
        }
        this.teamRows = this.teamRows.map((r) => (r.key === key ? { ...r, userId } : r));
        // Clear any stale "Complete this field" message now that a value exists.
        if (event.target && event.target.reportValidity) {
            event.target.reportValidity();
        }
    }

    handleRoleChange(event) {
        const key = this.rowKeyOf(event);
        const role = event.detail ? event.detail.value : null;
        if (key) {
            this.roleByKey[key] = role;
        }
        this.teamRows = this.teamRows.map((r) => (r.key === key ? { ...r, role } : r));
        if (event.target && event.target.reportValidity) {
            event.target.reportValidity();
        }
    }

    // Build the submit payload from the change-captured maps, with live-DOM
    // fallbacks for Lightning base components that do not always fire change
    // events in a way our row maps capture.
    collectTeamMembers() {
        const userFromDom = {};
        this.template.querySelectorAll('lightning-record-picker').forEach((picker) => {
            userFromDom[picker.dataset.key] = picker.value;
        });
        const roleFromDom = {};
        this.template.querySelectorAll('lightning-combobox').forEach((combo) => {
            roleFromDom[combo.dataset.key] = combo.value;
        });
        const members = [];
        this.teamRows.forEach((r) => {
            const userId = this.userIdByKey[r.key] || r.userId || userFromDom[r.key];
            if (userId) {
                members.push({
                    userId,
                    teamMemberRole: this.roleByKey[r.key] || roleFromDom[r.key] || null,
                    accessLevel: 'Read'
                });
            }
        });
        return members;
    }

    async toggleDefaultTeam() {
        this.showDefaultTeam = !this.showDefaultTeam;
        if (this.showDefaultTeam && this.defaultTeamMembers.length === 0) {
            this.loadingDefaultTeam = true;
            try {
                const data = await getDefaultTeamMembers();
                this.defaultTeamMembers = data.map((m, i) => ({ ...m, key: `def-${i}` }));
            } catch (e) {
                this.toast('Error', this.reduceError(e), 'error');
            } finally {
                this.loadingDefaultTeam = false;
            }
        }
    }

    get defaultTeamButtonLabel() {
        return this.showDefaultTeam ? 'Hide default team members' : 'View default team members';
    }

    get noDefaultTeam() {
        return !this.loadingDefaultTeam && this.defaultTeamMembers.length === 0;
    }

    handleCreateClick() {
        // Validate the team rows (user + role are both required) before creating anything.
        if (!this.validateTeamRows()) {
            return;
        }
        // Capture the team selections now, while the row components are still on screen.
        this.pendingTeamMembers = this.collectTeamMembers();
        const form = this.template.querySelector('lightning-record-edit-form');
        // Triggers form validation + the Opportunity insert; result handled in handleSuccess.
        this.isSaving = true;
        form.submit();
    }

    validateTeamRows() {
        let valid = true;
        this.template.querySelectorAll('lightning-record-picker').forEach((el) => {
            if (!el.reportValidity()) {
                valid = false;
            }
        });
        this.template.querySelectorAll('lightning-combobox').forEach((el) => {
            if (!el.reportValidity()) {
                valid = false;
            }
        });
        return valid;
    }

    handleSubmitError() {
        // record-edit-form surfaces field errors inline; just release the button.
        this.isSaving = false;
    }

    async handleSuccess(event) {
        const opportunityId = event.detail.id;
        // From a Contact the record itself is the primary contact; from an Account
        // the rep picks the primary contact in the form.
        const contactId = this.isAccount ? this.selectedContactId : this.recordId;
        try {
            await addTeamAndContactRole({
                opportunityId,
                contactId,
                teamMembers: this.pendingTeamMembers
            });
            this.toast('Success', 'Lead created with opportunity team.', 'success');
            this.closeQuickAction();
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: opportunityId, objectApiName: 'Opportunity', actionName: 'view' }
            });
        } catch (e) {
            // Opportunity exists but team/contact-role failed: tell the user plainly.
            this.toast(
                'Opportunity created, team add failed',
                this.reduceError(e),
                'warning'
            );
            this.closeQuickAction();
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: opportunityId, objectApiName: 'Opportunity', actionName: 'view' }
            });
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.closeQuickAction();
    }

    closeQuickAction() {
        // Only meaningful when launched as a quick action; a no-op elsewhere.
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'Unknown error';
    }
}
