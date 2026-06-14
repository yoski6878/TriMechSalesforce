import { LightningElement } from 'lwc';
import loadRecords from '@salesforce/apex/TaskCreatorController.loadRecords';
import createTasks from '@salesforce/apex/TaskCreatorController.createTasks';
import getAvailableReports from '@salesforce/apex/TaskCreatorReportSelector.getAvailableReports';
import getLeadDevelopmentUsers from '@salesforce/apex/TaskCreatorController.getLeadDevelopmentUsers';
import getAllStandardUsers from '@salesforce/apex/TaskCreatorController.getAllStandardUsers';
import USER_ID from '@salesforce/user/Id';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import xlsx from '@salesforce/resourceUrl/xlsx';
import papaparse from '@salesforce/resourceUrl/papaparse';

export default class TaskCreator extends LightningElement {
    papaparseLoaded = false;
    inputSource = '';
    isReportSelected = false;
    isFileSelected = false;
    fileColumnHeaders = [];
    whoIdMapping = '';
    whatIdMapping = '';
    ownerIdMapping = '';
    subjectMapping = '';
    dueDateMapping = '';
    showColumnMapping = false;
    mappingError = '';
    showSuccessMessage = false;
    successMessage = '';
    allStandardOwnerOptions = [];
    isSearchingAllUsers = false;
    validRecordCount = 0;
    ownerOptions = [];
    originalOwnerOptions = [];
    selectedOwners = [];
    taskSubject = '';
    dueDate = this.getDefaultDueDate();
    taskType = 'Call';
    loadedRecords = [];
    reportOptions = [];
    selectedReportId = '';
    isCreatingTasks = false;
    searchReportTerm = '';
    searchUserTerm = '';

    inputSourceOptions = [
        { label: 'Salesforce Report', value: 'report' },
        { label: 'CSV/Excel File', value: 'file' }
    ];
    taskTypeOptions = [
        { label: 'Call', value: 'Call' },
        { label: 'Email', value: 'Email' }
    ];

    get fileColumnOptions() {
        // Add a blank option for 'None' selection
        return [{ label: '-- None --', value: '' }].concat(this.fileColumnHeaders.map(h => ({ label: h, value: h })));
    }

    // Options for a given mapping dropdown, excluding any column already chosen in the OTHER dropdowns.
    // Always keeps the '-- None --' option and the dropdown's own current selection.
    mappingOptionsFor(currentKey) {
        const mappingKeys = ['whoIdMapping', 'whatIdMapping', 'ownerIdMapping', 'subjectMapping', 'dueDateMapping'];
        const usedByOthers = new Set(
            mappingKeys.filter(k => k !== currentKey).map(k => this[k]).filter(v => v)
        );
        return this.fileColumnOptions.filter(opt => opt.value === '' || !usedByOthers.has(opt.value));
    }

    get whoIdColumnOptions() { return this.mappingOptionsFor('whoIdMapping'); }
    get whatIdColumnOptions() { return this.mappingOptionsFor('whatIdMapping'); }
    get ownerIdColumnOptions() { return this.mappingOptionsFor('ownerIdMapping'); }
    get subjectColumnOptions() { return this.mappingOptionsFor('subjectMapping'); }
    get dueDateColumnOptions() { return this.mappingOptionsFor('dueDateMapping'); }

    // Clear the column-mapping UI and ALL five mappings. Used whenever the input
    // source/report/file changes or a run completes, so stale mappings can't leak
    // into the next selection (which would corrupt the disabled toggles and the
    // mutually-exclusive dropdown options).
    resetColumnMapping() {
        this.showColumnMapping = false;
        this.fileColumnHeaders = [];
        this.whoIdMapping = '';
        this.whatIdMapping = '';
        this.ownerIdMapping = '';
        this.subjectMapping = '';
        this.dueDateMapping = '';
        this.mappingError = '';
    }

    getDefaultDueDate() {
        const today = new Date();
        today.setDate(today.getDate() + 7);
        return this.toLocalIsoDate(today);
    }

    // Format a Date as YYYY-MM-DD using its LOCAL components.
    // (Date.toISOString() converts to UTC, which can shift the day for non-UTC users.)
    toLocalIsoDate(date) {
        const y = date.getFullYear();
        const m = String(date.getMonth() + 1).padStart(2, '0');
        const d = String(date.getDate()).padStart(2, '0');
        return `${y}-${m}-${d}`;
    }

    connectedCallback() {
        // Reset all tracked properties for a fresh state on every load
        this.inputSource = '';
        this.isReportSelected = false;
        this.isFileSelected = false;
        this.validRecordCount = 0;
        this.ownerOptions = [];
        this.selectedOwners = [];
        this.taskSubject = '';
        this.dueDate = this.getDefaultDueDate();
        this.taskType = 'Call';
        this.loadedRecords = [];
        this.reportOptions = [];
        this.selectedReportId = '';
        this.showSuccessMessage = false;
        this.successMessage = '';
        this.originalOwnerOptions = [];

        this.allStandardOwnerOptions = [];
        this.isSearchingAllUsers = false;

        this.resetColumnMapping();

        // Add 'Me' option first using USER_ID
        let meOption = [{ label: 'Me', value: USER_ID }];
        getLeadDevelopmentUsers()
            .then(users => {
                const bdrOptions = users.map(u => ({ label: u.Name, value: u.Id }));
                this.originalOwnerOptions = meOption.concat(bdrOptions); // Store original list (Development Reps)
                this.ownerOptions = this.originalOwnerOptions; // Initialize with original list
            })
            .catch(() => {
                this.originalOwnerOptions = meOption;
                this.ownerOptions = meOption;
            });
    }

    handleInputSourceChange(event) {
        this.inputSource = event.detail.value;
        this.isReportSelected = this.inputSource === 'report';
        this.isFileSelected = this.inputSource === 'file';
        this.validRecordCount = 0;
        this.loadedRecords = [];
        this.searchReportTerm = '';
        this.showSuccessMessage = false; // Clear prior success banner when starting a new batch
        // Hide mapping window on input source change
        this.resetColumnMapping();
        if (this.isReportSelected) {
            getAvailableReports()
                .then(result => {
                    this.reportOptions = result.map(r => ({ label: r.Name, value: r.Id }));
                })
            .catch(() => {
                this.reportOptions = [];
            });
        }
    }

    handleReportSearch(event) {
        this.searchReportTerm = event.detail.value;
    }

    handleClearSearch() {
        this.searchReportTerm = '';
    }

    handleUserSearch(event) {
        this.searchUserTerm = event.detail.value;
        // If searching and haven't loaded all users yet, fetch them
        if (this.searchUserTerm && this.searchUserTerm.length > 0 && this.allStandardOwnerOptions.length === 0 && !this.isSearchingAllUsers) {
            this.isSearchingAllUsers = true;
            getAllStandardUsers()
                .then(users => {
                    this.allStandardOwnerOptions = users.map(u => ({ label: u.Name, value: u.Id }));
                    this.isSearchingAllUsers = false;
                })
                .catch(() => {
                    this.isSearchingAllUsers = false;
                });
        }
    }

    handleClearUserSearch() {
        this.searchUserTerm = '';
        // Do not reset ownerOptions or selectedOwners here; just clear the search term and search state
        this.isSearchingAllUsers = false;
    }

    get filteredReportOptions() {
        if (!this.searchReportTerm) {
            return this.reportOptions;
        }
        const searchTerm = this.searchReportTerm.toLowerCase();
        return this.reportOptions.filter(option => 
            option.label.toLowerCase().includes(searchTerm)
        );
    }

    handleReportLookupChange(event) {
        this.selectedReportId = event.detail.value;
        // Reset mapping window state
        this.resetColumnMapping();
        // Capture the requested id so we can discard a stale response if the user
        // switches reports before this callout resolves (responses can arrive out of order).
        const requestedReportId = this.selectedReportId;
        loadRecords({ inputSource: 'report', reportId: requestedReportId, fileContent: null })
            .then(result => {
                if (requestedReportId !== this.selectedReportId) return;
                // Always set loadedRecords to an array
                this.loadedRecords = Array.isArray(result.validRecords) ? result.validRecords : [];
                // Drive the badge from the same array that gates the mapping window so they can't disagree
                this.validRecordCount = this.loadedRecords.length;
                // Show mapping window if records loaded
                if (this.loadedRecords.length > 0) {
                    this.showMappingForLoadedRecords();
                } else {
                    this.mappingError = result.errors ? result.errors : 'No valid records found in the selected report.';
                    this.showColumnMapping = false;
                }
            })
            .catch(error => {
                if (requestedReportId !== this.selectedReportId) return;
                this.mappingError = error.body ? error.body.message : error.message;
                this.showColumnMapping = false;
            });
    }

    handleOwnerChange(event) {
        this.selectedOwners = event.detail.value;
    }

    handleFileUpload(event) {
        const file = event.target.files[0];
        if (!file) return;
        // Reset mapping window state
        this.resetColumnMapping();
        const fileName = file.name.toLowerCase();
        const fileExtension = fileName.split('.').pop();
        // Check if it's an Excel file
        if (fileExtension === 'xls' || fileExtension === 'xlsx') {
            this.processExcelFile(file);
        } else {
            // CSV: Use PapaParse for robust parsing
            if (!this.papaparseLoaded) {
                loadScript(this, papaparse)
                    .then(() => {
                        this.papaparseLoaded = true;
                        this.parseCsvFile(file);
                    })
                    .catch(error => {
                        this.mappingError = 'Error loading CSV parsing library: ' + error.message;
                    });
            } else {
                this.parseCsvFile(file);
            }
        }
    }

    parseCsvFile(file) {
        const reader = new FileReader();
        reader.onload = () => {
            try {
                // Use PapaParse to parse CSV
                const result = window.Papa.parse(reader.result, { header: true, skipEmptyLines: true });
                if (result.errors && result.errors.length > 0) {
                    this.mappingError = 'CSV Parse Error: ' + result.errors.map(e => e.message).join('; ');
                    return;
                }
                const data = result.data;
                if (data.length > 0) {
                    this.fileColumnHeaders = Object.keys(data[0]);
                    this.autoMapColumns(this.fileColumnHeaders);
                    this.showColumnMapping = true;
                    this.mappingError = '';
                    this.loadedRecords = data;
                    this.validRecordCount = data.length;
                    this.showMappingForLoadedRecords();
                } else {
                    this.mappingError = 'No records found in CSV file.';
                }
            } catch (error) {
                this.mappingError = 'Error parsing CSV file: ' + error.message;
            }
        };
        reader.onerror = () => {
            this.mappingError = 'Error reading CSV file.';
        };
        reader.readAsText(file);
    }

    handleWhoIdMappingChange(event) {
        this.whoIdMapping = event.detail.value;
    }
    handleWhatIdMappingChange(event) {
        this.whatIdMapping = event.detail.value;
    }
    handleOwnerIdMappingChange(event) {
        this.ownerIdMapping = event.detail.value;
    }
    handleSubjectMappingChange(event) {
        this.subjectMapping = event.detail.value;
    }
    handleDueDateMappingChange(event) {
        this.dueDateMapping = event.detail.value;
    }

    // Build column headers from the loaded rows (report, CSV, or Excel) and open the mapping UI.
    showMappingForLoadedRecords() {
        if (this.loadedRecords && this.loadedRecords.length > 0) {
            this.fileColumnHeaders = Object.keys(this.loadedRecords[0]);
            // Auto-map columns
            this.autoMapColumns(this.fileColumnHeaders);
            this.showColumnMapping = true;
            this.mappingError = '';
        } else {
            this.showColumnMapping = false;
            this.mappingError = 'No records available for mapping.';
        }
    }
    // Auto-map WhoId/WhatId/OwnerId/Subject/DueDate columns based on header names
    autoMapColumns(headers) {
        // Lowercase headers for easier matching
        const lowerHeaders = headers.map(h => h.toLowerCase());
        // Possible names for WhoId (Contact/Lead)
        const whoIdCandidates = [
            'contactid', 'contact id', 'contact',
            'leadid', 'lead id', 'lead',
            'whoid', 'who id', 'who'
        ];
        // Possible names for WhatId (Account/Opportunity/Other)
        const whatIdCandidates = [
            'accountid', 'account id', 'account',
            'opportunityid', 'opportunity id', 'opportunity',
            'whatid', 'what id', 'what'
        ];
        // Possible names for OwnerId
        const ownerIdCandidates = [
            'ownerid', 'owner id', 'owner', 'task owner', 'assignedto', 'assigned to', 'assigned_user_id', 'assigned user id'
        ];
        // Possible names for Subject
        const subjectCandidates = [
            'subject', 'task subject', 'task_subject', 'task name', 'name', 'title'
        ];
        // Possible names for Due Date
        const dueDateCandidates = [
            'duedate', 'due date', 'activitydate', 'task due', 'task_due', 'date'
        ];
        // Find best match for WhoId
        let whoMatch = '';
        for (const candidate of whoIdCandidates) {
            const idx = lowerHeaders.findIndex(h => h === candidate || h.replace(/[_\s]/g, '') === candidate.replace(/[_\s]/g, ''));
            if (idx !== -1) {
                whoMatch = headers[idx];
                break;
            }
        }
        // Find best match for WhatId
        let whatMatch = '';
        for (const candidate of whatIdCandidates) {
            const idx = lowerHeaders.findIndex(h => h === candidate || h.replace(/[_\s]/g, '') === candidate.replace(/[_\s]/g, ''));
            if (idx !== -1) {
                whatMatch = headers[idx];
                break;
            }
        }
        // Find best match for OwnerId
        let ownerMatch = '';
        for (const candidate of ownerIdCandidates) {
            const idx = lowerHeaders.findIndex(h => h === candidate || h.replace(/[_\s]/g, '') === candidate.replace(/[_\s]/g, ''));
            if (idx !== -1) {
                ownerMatch = headers[idx];
                break;
            }
        }
        // Find best match for Subject
        let subjectMatch = '';
        for (const candidate of subjectCandidates) {
            const idx = lowerHeaders.findIndex(h => h === candidate || h.replace(/[_\s]/g, '') === candidate.replace(/[_\s]/g, ''));
            if (idx !== -1) {
                subjectMatch = headers[idx];
                break;
            }
        }
        // Find best match for Due Date
        let dueDateMatch = '';
        for (const candidate of dueDateCandidates) {
            const idx = lowerHeaders.findIndex(h => h === candidate || h.replace(/[_\s]/g, '') === candidate.replace(/[_\s]/g, ''));
            if (idx !== -1) {
                dueDateMatch = headers[idx];
                break;
            }
        }
        this.whoIdMapping = whoMatch;
        this.whatIdMapping = whatMatch;
        this.ownerIdMapping = ownerMatch;
        this.subjectMapping = subjectMatch;
        this.dueDateMapping = dueDateMatch;
    }

    processExcelFile(file) {
        // Load the xlsx library first
        loadScript(this, xlsx)
            .then(() => {
                const reader = new FileReader();
                reader.onload = (event) => {
                    try {
                        const data = new Uint8Array(event.target.result);
                        // Use window.XLSX to access the loaded library
                        // cellDates makes date cells come back as JS Date objects rather than
                        // Excel serial numbers, so convertToIsoDate can handle them.
                        const workbook = window.XLSX.read(data, { type: 'array', cellDates: true });

                        // Get the first worksheet and convert it to row objects keyed by header.
                        // This yields the same shape as the CSV path, so all columns are
                        // preserved and the mapping dropdowns can map any of them.
                        const firstSheetName = workbook.SheetNames[0];
                        const worksheet = workbook.Sheets[firstSheetName];
                        const jsonData = window.XLSX.utils.sheet_to_json(worksheet, { defval: '' });

                        if (jsonData.length > 0) {
                            this.fileColumnHeaders = Object.keys(jsonData[0]);
                            this.autoMapColumns(this.fileColumnHeaders);
                            this.showColumnMapping = true;
                            this.mappingError = '';
                            this.loadedRecords = jsonData;
                            this.validRecordCount = jsonData.length;
                            this.showMappingForLoadedRecords();
                        } else {
                            this.mappingError = 'No records found in Excel file.';
                        }
                    } catch (error) {
                        this.mappingError = 'Error processing Excel file: ' + error.message;
                    }
                };
                reader.onerror = () => {
                    this.mappingError = 'Error reading Excel file.';
                };
                reader.readAsArrayBuffer(file);
            })
            .catch(error => {
                this.mappingError = 'Error loading Excel processing library: ' + error.message;
            });
    }

    handleSubjectChange(event) {
        this.taskSubject = event.detail.value;
    }

    handleDueDateChange(event) {
        this.dueDate = event.detail.value;
    }

    handleTaskTypeChange(event) {
        this.taskType = event.detail.value;
    }

    get isCreateTasksDisabled() {
        // Disable if no valid records or (no owners selected and no ownerIdMapping)
        const hasOwners = (this.selectedOwners && this.selectedOwners.length > 0) || this.ownerIdMapping;
        return !(this.loadedRecords && this.loadedRecords.length > 0 && hasOwners);
    }

    get isCreateTasksButtonDisabled() {
        // Disable if creating tasks OR if normal disable conditions
        return this.isCreatingTasks || this.isCreateTasksDisabled;
    }

    // Show the neutral "what to do next" hints only when the button is disabled and
    // we're not already showing a success confirmation (so a finished run doesn't look like an error).
    get showSetupHints() {
        return this.isCreateTasksDisabled && !this.showSuccessMessage;
    }

    // Preserve selected users in the filtered list to prevent loss during search
    get filteredOwnerOptionsWithSelected() {
        // Always show all selected users, even if not in the current ownerOptions or search results
        let baseOptions;
        if (this.allStandardOwnerOptions.length > 0) {
            baseOptions = this.allStandardOwnerOptions;
        } else {
            baseOptions = this.originalOwnerOptions;
        }
        let filteredOptions;
        if (this.searchUserTerm) {
            const searchTerm = this.searchUserTerm.toLowerCase();
            filteredOptions = baseOptions.filter(option => 
                option.label.toLowerCase().includes(searchTerm)
            );
        } else {
            // When not searching, show the original ownerOptions (Development Reps)
            filteredOptions = this.ownerOptions;
        }
        // Always include selected users, even if not in filteredOptions
        const selectedIds = new Set(this.selectedOwners);
        // Use all loaded users for selectedOptions to avoid losing users from all users search
        const allLoadedOptions = this.allStandardOwnerOptions.length > 0 ? this.allStandardOwnerOptions : this.originalOwnerOptions;
        const selectedOptions = allLoadedOptions.filter(option => selectedIds.has(option.value));
        const filteredOptionIds = new Set(filteredOptions.map(opt => opt.value));
        const additionalOptions = selectedOptions.filter(option => !filteredOptionIds.has(option.value));
        return [...filteredOptions, ...additionalOptions];
    }


    handleCreateTasks() {
        // Prevent multiple clicks during task creation
        if (this.isCreatingTasks) {
            return;
        }
        // WhoId (Contact/Lead) and WhatId (Account/Opportunity) are now optional
        this.mappingError = '';
        this.showSuccessMessage = false;
        this.isCreatingTasks = true;

        // Normalize a mapped cell value to a trimmed string. Excel returns numbers/Dates,
        // so this guards the Apex String casts against ClassCastExceptions.
        const toStr = (v) => (v === null || v === undefined) ? '' : String(v).trim();

        // Convert a due-date cell (string, Excel Date object, or epoch-ms number) to YYYY-MM-DD
        // using local components. Returns '' when empty, or null when present-but-unparseable.
        const convertToIsoDate = (value) => {
            if (value === null || value === undefined || value === '') return '';
            if (value instanceof Date) {
                return isNaN(value.getTime()) ? null : this.toLocalIsoDate(value);
            }
            const str = String(value).trim();
            if (str === '') return '';
            // Already in ISO format
            if (/^\d{4}-\d{2}-\d{2}$/.test(str)) return str;
            // Try M/D/YYYY or MM/DD/YYYY
            const match = str.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
            if (match) {
                const m = match[1].padStart(2, '0');
                const d = match[2].padStart(2, '0');
                return `${match[3]}-${m}-${d}`;
            }
            // Fallback: let the engine parse it, then format in local time
            const dObj = new Date(str);
            return isNaN(dObj.getTime()) ? null : this.toLocalIsoDate(dObj);
        };

        let userFriendlyErrors = [];
        let validRecords = (this.loadedRecords || []).map((rec, idx) => {
            let dueDateValue = this.dueDateMapping ? rec[this.dueDateMapping] : this.dueDate;
            let convertedDueDate = convertToIsoDate(dueDateValue);
            if (dueDateValue && !convertedDueDate) {
                userFriendlyErrors.push(`Row ${idx + 1}: Invalid due date format "${dueDateValue}". Use YYYY-MM-DD or MM/DD/YYYY.`);
            }
            return {
                contactId: this.whoIdMapping ? toStr(rec[this.whoIdMapping]) : '',
                accountId: this.whatIdMapping ? toStr(rec[this.whatIdMapping]) : '',
                ownerId: this.ownerIdMapping ? toStr(rec[this.ownerIdMapping]) : '',
                subject: this.subjectMapping ? toStr(rec[this.subjectMapping]) : this.taskSubject,
                dueDate: convertedDueDate || '',
                type: this.taskType
            };
        });
        // If no ownerIdMapping, assign owners in round robin
        if (!this.ownerIdMapping && this.selectedOwners && this.selectedOwners.length > 0) {
            let rrRecords = validRecords.map((rec, idx) => {
                const ownerId = this.selectedOwners[idx % this.selectedOwners.length];
                return { ...rec, ownerId };
            });
            validRecords = rrRecords;
        } else if (this.ownerIdMapping) {
            // Filter out records with no ownerId if mapping is set
            validRecords = validRecords.filter(r => r.ownerId);
        }
        if (userFriendlyErrors.length > 0) {
            this.mappingError = userFriendlyErrors.join(' ');
            this.isCreatingTasks = false;
            return;
        }
        if (validRecords.length === 0) {
            this.mappingError = 'No valid records to create tasks.';
            this.isCreatingTasks = false; // Reset flag on error
            return;
        }

        // Call Apex once with all records
        createTasks({ tasks: validRecords })
            .then(result => {
                if (result.errors && result.errors.includes('Large job submitted')) {
                    // Reset the form
                    this.inputSource = '';
                    this.isReportSelected = false;
                    this.isFileSelected = false;
                    this.validRecordCount = 0;
                    this.loadedRecords = [];
                    this.selectedReportId = '';
                    this.selectedOwners = [];
                    this.taskSubject = '';
                    this.dueDate = this.getDefaultDueDate();
                    this.resetColumnMapping();
                    this.isCreatingTasks = false;
                    // Persistent inline confirmation + toast
                    this.successMessage = 'Your tasks have been submitted and are being created in the background. You’ll be notified by email when they’re done — you can safely leave this page.';
                    this.showSuccessMessage = true;
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Task Creation Started',
                            message: 'Tasks have been submitted and are being created in the background. You may leave this page.',
                            variant: 'info',
                            mode: 'dismissable'
                        })
                    );
                    return;
                }
                this.showToast(result.created, result.skipped);
                this.isCreatingTasks = false;
                if (!result.created) {
                    // Nothing was created (all skipped/invalid) — keep the form so the user can fix and retry.
                    this.mappingError = result.errors
                        ? result.errors
                        : 'No tasks were created. Please check your data and try again.';
                    return;
                }
                // Success: show a persistent confirmation and reset the form for the next batch.
                this.successMessage = this.buildSuccessMessage(result.created, result.skipped);
                this.showSuccessMessage = true;
                this.inputSource = '';
                this.isReportSelected = false;
                this.isFileSelected = false;
                this.validRecordCount = 0;
                this.loadedRecords = [];
                this.selectedReportId = '';
                this.selectedOwners = [];
                this.taskSubject = '';
                this.dueDate = this.getDefaultDueDate();
                this.resetColumnMapping();
            })
            .catch(error => {
                this.mappingError = error.body ? error.body.message : error.message;
                this.isCreatingTasks = false;
            });
    }

    // Computed property: disable owner selection if mapping is set
    get isOwnerMappingActive() {
        return !!this.ownerIdMapping;
    }
    // Computed property: disable subject input if mapping is set
    get isSubjectMappingActive() {
        return !!this.subjectMapping;
    }
    // Computed property: disable due date input if mapping is set
    get isDueDateMappingActive() {
        return !!this.dueDateMapping;
    }

    buildSuccessMessage(created, skipped) {
        const base = `${created} task${created !== 1 ? 's' : ''} created successfully`;
        return skipped > 0
            ? `${base}, ${skipped} record${skipped !== 1 ? 's' : ''} skipped.`
            : `${base}.`;
    }

    showToast(created, skipped) {
        let title, message, variant;
        
        if (created === 0) {
            title = 'No Records Created';
            message = 'No tasks were created. Please check your data and try again.';
            variant = 'error';
        } else if (skipped === 0) {
            title = 'Records Created Successfully';
            message = `${created} record${created !== 1 ? 's' : ''} created successfully.`;
            variant = 'success';
        } else {
            title = 'Records Created with Skips';
            message = `${created} record${created !== 1 ? 's' : ''} created, ${skipped} record${skipped !== 1 ? 's' : ''} skipped.`;
            variant = 'warning';
        }
        
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }
}