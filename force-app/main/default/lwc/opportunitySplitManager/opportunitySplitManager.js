import { LightningElement, api, wire, track } from 'lwc';
import getOpportunitySplits from '@salesforce/apex/OpportunitySplitController.getOpportunitySplits';
import createOpportunitySplits from '@salesforce/apex/OpportunitySplitController.createOpportunitySplits';
import getOpportunityTeamMembers from '@salesforce/apex/OpportunitySplitController.getOpportunityTeamMembers';
import isCurrentUserTeamMember from '@salesforce/apex/OpportunitySplitController.isCurrentUserTeamMember';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class OpportunitySplitManager extends LightningElement {
    @api recordId;
    @track editableSplits = [];
    @track canEditSplits = false;
    @track isDirty = false;
    // helper getter used by template to hide delete button on first row
    get indexIsFirst() {
        // In LWC template, for:index exposes an index variable per iteration.
        // We expose a boolean getter name here to satisfy the template binding,
        // but LWC evaluates template expressions in the repeat scope first.
        // We will not use this getter's return value; it's only to avoid linting issues.
        return false;
    }
    @track users = [];
    @track isLoading = false;
    @track error;
    wiredSplitsResult;
    splitsDataCache = null;
    usersLoaded = false;

    connectedCallback() {
        this.checkEditPermission();
        this.loadUsers();
    }

    checkEditPermission() {
        this.isLoading = true;
        isCurrentUserTeamMember({ opportunityId: this.recordId })
            .then(result => {
                this.canEditSplits = result;
                this.isLoading = false;
            })
            .catch(error => {
                this.canEditSplits = false;
                this.showError('Failed to check edit permission', error);
            });
    }

    @wire(getOpportunitySplits, { opportunityId: '$recordId' })
    wiredSplits(result) {
        this.wiredSplitsResult = result;
        const { error, data } = result;
        if (this.recordId && data) {
            this.splitsDataCache = data;
            if (this.usersLoaded) {
                this.processRows();
            }
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.showToast('Error', 'Failed to load opportunity splits: ' + (error.body?.message || error.message || 'Unknown error'), 'error');
        }
    }

    loadUsers() {
        this.users = []; // Force clear users to ensure UI re-renders
        this.isLoading = true;
        return getOpportunityTeamMembers({ opportunityId: this.recordId })
            .then(result => {
                // eslint-disable-next-line no-console
                console.log('Loaded team members:', result);
                this.users = result.map(user => ({ label: user.Name, value: user.Id }));
                this.usersLoaded = true;
                if (this.splitsDataCache) {
                    this.processRows();
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.showError('Failed to load team member users', error);
            });
    }

    // Build exactly one row per active team member.
    // If a split exists for a team member, show it; otherwise, show an empty row.
    // Number of rows always equals number of team members.
    processRows() {
        if (!this.usersLoaded) {
            this.editableSplits = [];
            return;
        }
        // Map existing splits by owner for quick lookup
        const splitByOwner = new Map();
        if (Array.isArray(this.splitsDataCache)) {
            this.splitsDataCache.forEach(s => {
                if (s && s.SplitOwnerId) {
                    splitByOwner.set(s.SplitOwnerId, s);
                }
            });
        }
        // For each team member, render row with that user's split if present, else blank row
        this.editableSplits = this.users.map((u, idx) => {
            const existing = splitByOwner.get(u.value);
            return {
                Id: existing?.Id || `row-${idx}`,
                SplitOwnerId: u.value, // preselect the team member to keep parity and avoid confusion
                SplitPercentage: existing?.SplitPercentage ?? '',
                SplitAmount: existing?.SplitAmount ?? '',
                SplitNote: existing?.SplitNote ?? ''
            };
        });
    }

    handleTableInputChange(event) {
        const id = event.target.dataset.id;
        const field = event.target.dataset.field;
        const value = event.target.value;
        let splits = this.editableSplits.map(split => {
            if (split.Id === id) {
                return { ...split, [field]: value };
            }
            return split;
        });
        this.editableSplits = splits;
        this.isDirty = true;
    }

    // "Delete" clears the row fields but keeps the row to maintain parity with team size.
    handleDeleteRow(event) {
        const id = event.currentTarget.dataset.id;
        // If the row is a manually added row (not from Salesforce), remove it entirely
        if (id && id.startsWith('row-')) {
            this.editableSplits = this.editableSplits.filter(r => r.Id !== id);
            return;
        }
        // Otherwise, clear the row fields but keep the row to maintain parity with team size
        this.editableSplits = this.editableSplits.map(r => {
            if (r.Id === id) {
                return {
                    ...r,
                    SplitOwnerId: '',
                    SplitPercentage: '',
                    SplitNote: ''
                };
            }
            return r;
        });

        // After clearing, if exactly one row still has a selected user, force that one to 100% and others blank
        const selectedRows = this.editableSplits.filter(r => r.SplitOwnerId);
        if (selectedRows.length === 1) {
            const onlyId = selectedRows[0].Id;
            this.editableSplits = this.editableSplits.map(r => {
                if (r.Id === onlyId) {
                    return { ...r, SplitPercentage: 100 };
                }
                // Ensure all other rows have blank percentage
                return { ...r, SplitPercentage: r.SplitOwnerId ? r.SplitPercentage : '' };
            });
        }
        this.isDirty = true;
    }

    handleSaveAll() {
        // Build active rows = rows having a selected user and numeric percentage
        let activeRows = this.editableSplits.filter(
            split => split.SplitOwnerId && split.SplitPercentage !== '' && split.SplitPercentage !== null && !isNaN(Number(split.SplitPercentage))
        ).map(s => ({
            ...s,
            SplitPercentage: Number(s.SplitPercentage)
        }));

        // If only one active row remains, force it to 100% to allow single-operation delete
        if (activeRows.length === 1) {
            activeRows = activeRows.map(r => ({ ...r, SplitPercentage: 100 }));
        } else if (activeRows.length > 1) {
            // Validate client-side that totals equal 100 to avoid server rejection
            const total = activeRows.reduce((acc, r) => acc + (Number.isFinite(r.SplitPercentage) ? r.SplitPercentage : 0), 0);
            // Use fixed 2 decimals comparison
            if (Number(total.toFixed(2)) !== 100) {
                this.showToast('Error', `Split percentages must sum to 100%. Current total: ${total}`, 'error');
                return;
            }
        }

        // Build payload only from active rows; cleared rows are excluded so Apex deletes them
        let splitObjs = activeRows.map(split => {
            return {
                SplitOwnerId: split.SplitOwnerId,
                SplitPercentage: Number(split.SplitPercentage),
                OpportunityId: this.recordId,
                SplitTypeId: '1494V00000009uwQAA',
                SplitNote: split.SplitNote
            };
        });

        // Debug: log what is being sent to Apex
        // eslint-disable-next-line no-console
        console.log('Saving splits:', JSON.stringify(splitObjs));

        if (splitObjs.length === 0) {
            this.showToast('Error', 'No splits to save. Please fill at least one row with a user and percentage.', 'error');
            return;
        }

        this.isLoading = true;
        createOpportunitySplits({ splitObjs })
            .then(result => {
                if (result && result.startsWith('Success')) {
                    this.showToast('Success', result, 'success');
                    refreshApex(this.wiredSplitsResult);
                } else {
                    this.showError(result || 'Failed to save splits');
                }
            })
            .catch(error => {
                this.showError('Failed to save splits', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCancel() {
        this.isLoading = true;
        this.usersLoaded = false;
        refreshApex(this.wiredSplitsResult).then(() => {
            this.loadUsers().finally(() => {
                this.isLoading = false;
            });
        });
        this.isDirty = false;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }

    handleRefresh() {
        this.isLoading = true;
        this.usersLoaded = false;
        refreshApex(this.wiredSplitsResult).then(() => {
            this.loadUsers().finally(() => {
                this.isLoading = false;
            });
        });
    }

    showError(message, error) {
        this.error = {
            message: message,
            details: error?.body?.message || error?.message || JSON.stringify(error)
        };
        this.isLoading = false;
        this.showToast('Error', message, 'error');
    }

    get disableEdit() {
        return !this.canEditSplits;
    }
}