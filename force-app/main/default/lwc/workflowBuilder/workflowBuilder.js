import { LightningElement, track } from 'lwc';
import getMyWorkflows from '@salesforce/apex/SchedulingController.getMyWorkflows';
import getWorkflowDetail from '@salesforce/apex/SchedulingController.getWorkflowDetail';
import saveWorkflow from '@salesforce/apex/SchedulingController.saveWorkflow';
import saveWorkflowStep from '@salesforce/apex/SchedulingController.saveWorkflowStep';
import deleteWorkflowStep from '@salesforce/apex/SchedulingController.deleteWorkflowStep';
import getActiveEventTypes from '@salesforce/apex/SchedulingController.getActiveEventTypes';

export default class WorkflowBuilder extends LightningElement {
    @track workflows = [];
    @track workflowDetail;
    @track isLoading = false;
    @track error;
    @track showNewWorkflowModal = false;
    @track showStepModal = false;

    newWorkflowName = '';
    newWorkflowTriggerEvent = 'New_Booking';

    editWorkflowName = '';
    editWorkflowTriggerEvent = 'New_Booking';
    editWorkflowEventTypeId = '';
    editWorkflowIsActive = true;
    editWorkflowTimeOffset = '';

    editingStepId;
    stepActionType = 'Email';
    stepRecipient = 'Attendee';
    stepTemplate = '';
    stepWebhookUrl = '';
    stepSortOrder = 1;

    eventTypeOptions = [];

    get hasWorkflows() {
        return this.workflows && this.workflows.length > 0;
    }

    get noWorkflows() {
        return !this.hasWorkflows;
    }

    get notLoading() {
        return !this.isLoading;
    }

    get isListView() {
        return !this.workflowDetail;
    }

    get isDetailView() {
        return !!this.workflowDetail;
    }

    get hasSteps() {
        return this.workflowDetail && this.workflowDetail.steps && this.workflowDetail.steps.length > 0;
    }

    get triggerEventOptions() {
        return [
            { label: 'New Booking', value: 'New_Booking' },
            { label: 'Booking Confirmed', value: 'Booking_Confirmed' },
            { label: 'Booking Cancelled', value: 'Booking_Cancelled' },
            { label: 'Booking Rescheduled', value: 'Booking_Rescheduled' },
            { label: 'Before Event', value: 'Before_Event' },
            { label: 'After Event', value: 'After_Event' }
        ];
    }

    get actionTypeOptions() {
        return [
            { label: 'Email', value: 'Email' },
            { label: 'SMS', value: 'SMS' },
            { label: 'Webhook', value: 'Webhook' }
        ];
    }

    get recipientOptions() {
        return [
            { label: 'Host', value: 'Host' },
            { label: 'Attendee', value: 'Attendee' },
            { label: 'Both', value: 'Both' }
        ];
    }

    get stepModalTitle() {
        return this.editingStepId ? 'Edit Step' : 'Add Step';
    }

    get showTimeOffset() {
        return this.editWorkflowTriggerEvent === 'Before_Event'
            || this.editWorkflowTriggerEvent === 'After_Event';
    }

    get showNewTimeOffset() {
        return this.newWorkflowTriggerEvent === 'Before_Event'
            || this.newWorkflowTriggerEvent === 'After_Event';
    }

    get isEmailOrSmsStep() {
        return this.stepActionType === 'Email' || this.stepActionType === 'SMS';
    }

    get isWebhookStep() {
        return this.stepActionType === 'Webhook';
    }

    connectedCallback() {
        this.loadWorkflows();
        this.loadEventTypes();
    }

    async loadWorkflows() {
        this.isLoading = true;
        this.error = undefined;
        try {
            this.workflows = await getMyWorkflows();
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    async loadEventTypes() {
        try {
            const eventTypes = await getActiveEventTypes({ hostUserId: null });
            this.eventTypeOptions = [
                { label: 'All Event Types', value: '' },
                ...eventTypes.map(et => ({ label: et.Name, value: et.Id }))
            ];
        } catch (err) {
            this.error = this.extractError(err);
        }
    }

    async loadWorkflowDetail(workflowId) {
        this.isLoading = true;
        this.error = undefined;
        try {
            this.workflowDetail = await getWorkflowDetail({ workflowId });
            this.editWorkflowName = this.workflowDetail.name;
            this.editWorkflowTriggerEvent = this.workflowDetail.triggerEvent;
            this.editWorkflowEventTypeId = this.workflowDetail.eventTypeId || '';
            this.editWorkflowIsActive = this.workflowDetail.isActive;
            this.editWorkflowTimeOffset = this.workflowDetail.timeOffsetMinutes != null
                ? String(this.workflowDetail.timeOffsetMinutes)
                : '';
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleNewWorkflowClick() {
        this.newWorkflowName = '';
        this.newWorkflowTriggerEvent = 'New_Booking';
        this.showNewWorkflowModal = true;
    }

    handleNewWorkflowNameChange(event) {
        this.newWorkflowName = event.target.value;
    }

    handleNewWorkflowTriggerChange(event) {
        this.newWorkflowTriggerEvent = event.detail.value;
    }

    async handleCreateWorkflow() {
        if (!this.newWorkflowName) {
            this.error = 'Workflow name is required';
            return;
        }

        this.isLoading = true;
        this.error = undefined;
        try {
            const workflow = await saveWorkflow({
                workflowId: null,
                name: this.newWorkflowName,
                triggerEvent: this.newWorkflowTriggerEvent,
                eventTypeId: null,
                isActive: true,
                timeOffsetMinutes: null
            });
            this.showNewWorkflowModal = false;
            await this.loadWorkflows();
            await this.loadWorkflowDetail(workflow.Id);
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleCancelNewWorkflow() {
        this.showNewWorkflowModal = false;
    }

    handleEditWorkflowClick(event) {
        this.loadWorkflowDetail(event.currentTarget.dataset.id);
    }

    handleBackToList() {
        this.workflowDetail = null;
        this.loadWorkflows();
    }

    handleEditWorkflowNameChange(event) {
        this.editWorkflowName = event.target.value;
    }

    handleEditWorkflowTriggerChange(event) {
        this.editWorkflowTriggerEvent = event.detail.value;
    }

    handleEditWorkflowEventTypeChange(event) {
        this.editWorkflowEventTypeId = event.detail.value;
    }

    handleEditWorkflowIsActiveChange(event) {
        this.editWorkflowIsActive = event.target.checked;
    }

    handleEditWorkflowTimeOffsetChange(event) {
        this.editWorkflowTimeOffset = event.target.value;
    }

    async handleSaveWorkflowDetails() {
        if (!this.editWorkflowName) {
            this.error = 'Workflow name is required';
            return;
        }

        this.isLoading = true;
        this.error = undefined;
        try {
            const timeOffset = this.showTimeOffset && this.editWorkflowTimeOffset
                ? parseFloat(this.editWorkflowTimeOffset)
                : null;

            await saveWorkflow({
                workflowId: this.workflowDetail.id,
                name: this.editWorkflowName,
                triggerEvent: this.editWorkflowTriggerEvent,
                eventTypeId: this.editWorkflowEventTypeId || null,
                isActive: this.editWorkflowIsActive,
                timeOffsetMinutes: timeOffset
            });
            await this.loadWorkflowDetail(this.workflowDetail.id);
            await this.loadWorkflows();
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleAddStepClick() {
        this.editingStepId = null;
        this.stepActionType = 'Email';
        this.stepRecipient = 'Attendee';
        this.stepTemplate = '';
        this.stepWebhookUrl = '';
        this.stepSortOrder = (this.workflowDetail.steps?.length || 0) + 1;
        this.showStepModal = true;
    }

    handleEditStepClick(event) {
        const stepId = event.currentTarget.dataset.id;
        const step = this.workflowDetail.steps.find(s => s.id === stepId);
        if (!step) return;

        this.editingStepId = step.id;
        this.stepActionType = step.actionType;
        this.stepRecipient = step.recipient;
        this.stepTemplate = step.template || '';
        this.stepWebhookUrl = step.webhookUrl || '';
        this.stepSortOrder = step.sortOrder || 1;
        this.showStepModal = true;
    }

    handleStepActionTypeChange(event) {
        this.stepActionType = event.detail.value;
    }

    handleStepRecipientChange(event) {
        this.stepRecipient = event.detail.value;
    }

    handleStepTemplateChange(event) {
        this.stepTemplate = event.target.value;
    }

    handleStepWebhookUrlChange(event) {
        this.stepWebhookUrl = event.target.value;
    }

    handleStepSortOrderChange(event) {
        this.stepSortOrder = parseInt(event.target.value, 10) || 1;
    }

    async handleSaveStep() {
        if (!this.stepActionType) {
            this.error = 'Action type is required';
            return;
        }

        this.isLoading = true;
        this.error = undefined;
        try {
            await saveWorkflowStep({
                stepId: this.editingStepId,
                workflowId: this.workflowDetail.id,
                actionType: this.stepActionType,
                recipient: this.isEmailOrSmsStep ? this.stepRecipient : null,
                template: this.isEmailOrSmsStep ? this.stepTemplate : null,
                webhookUrl: this.isWebhookStep ? this.stepWebhookUrl : null,
                sortOrder: this.stepSortOrder
            });
            this.showStepModal = false;
            await this.loadWorkflowDetail(this.workflowDetail.id);
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleCancelStep() {
        this.showStepModal = false;
    }

    async handleDeleteStep(event) {
        this.isLoading = true;
        this.error = undefined;
        try {
            await deleteWorkflowStep({ stepId: event.currentTarget.dataset.id });
            await this.loadWorkflowDetail(this.workflowDetail.id);
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    get displayWorkflows() {
        return (this.workflows || []).map(w => ({
            ...w,
            statusLabel: w.Is_Active__c ? 'Active' : 'Inactive',
            eventTypeLabel: w.Event_Type__r ? w.Event_Type__r.Name : 'All Event Types'
        }));
    }

    extractError(err) {
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'An unexpected error occurred';
    }
}
