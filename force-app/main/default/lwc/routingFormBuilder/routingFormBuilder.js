import { LightningElement, track } from 'lwc';
import getActiveRoutingForms from '@salesforce/apex/SchedulingController.getActiveRoutingForms';
import getRoutingFormDetail from '@salesforce/apex/SchedulingController.getRoutingFormDetail';
import saveRoutingForm from '@salesforce/apex/SchedulingController.saveRoutingForm';
import saveRoutingField from '@salesforce/apex/SchedulingController.saveRoutingField';
import saveRoutingRoute from '@salesforce/apex/SchedulingController.saveRoutingRoute';
import deleteRoutingField from '@salesforce/apex/SchedulingController.deleteRoutingField';
import deleteRoutingRoute from '@salesforce/apex/SchedulingController.deleteRoutingRoute';
import getActiveEventTypes from '@salesforce/apex/SchedulingController.getActiveEventTypes';

export default class RoutingFormBuilder extends LightningElement {
    @track forms = [];
    @track formDetail;
    @track isLoading = false;
    @track error;
    @track showNewFormModal = false;
    @track showFieldModal = false;
    @track showRouteModal = false;

    newFormName = '';
    newFormDescription = '';
    editFormName = '';
    editFormDescription = '';

    editingFieldId;
    fieldName = '';
    fieldType = 'Text';
    fieldOptions = '';

    editingRouteId;
    routeTargetEventTypeId = '';
    routeConditionFieldId = '';
    routeConditionOperator = 'equals';
    routeConditionValue = '';

    get hasForms() {
        return this.forms && this.forms.length > 0;
    }

    get noForms() {
        return !this.hasForms;
    }

    get notLoading() {
        return !this.isLoading;
    }

    get isListView() {
        return !this.formDetail;
    }

    get isDetailView() {
        return !!this.formDetail;
    }

    get hasFields() {
        return this.formDetail && this.formDetail.fields && this.formDetail.fields.length > 0;
    }

    get hasRoutes() {
        return this.formDetail && this.formDetail.routes && this.formDetail.routes.length > 0;
    }

    get fieldTypeOptions() {
        return [
            { label: 'Text', value: 'Text' },
            { label: 'Select', value: 'Select' },
            { label: 'Multi-Select', value: 'MultiSelect' },
            { label: 'Email', value: 'Email' },
            { label: 'Phone', value: 'Phone' }
        ];
    }

    get operatorOptions() {
        return [
            { label: 'Equals', value: 'equals' },
            { label: 'Not Equals', value: 'not_equals' },
            { label: 'Contains', value: 'contains' },
            { label: 'Starts With', value: 'starts_with' }
        ];
    }

    get fieldModalTitle() {
        return this.editingFieldId ? 'Edit Field' : 'Add Field';
    }

    get routeModalTitle() {
        return this.editingRouteId ? 'Edit Route' : 'Add Route';
    }

    get showFieldOptions() {
        return this.fieldType === 'Select' || this.fieldType === 'MultiSelect';
    }

    get conditionFieldOptions() {
        if (!this.formDetail || !this.formDetail.fields) {
            return [];
        }
        return this.formDetail.fields.map(f => ({ label: f.name, value: f.id }));
    }

    eventTypeOptions = [];

    connectedCallback() {
        this.loadForms();
        this.loadEventTypes();
    }

    async loadForms() {
        this.isLoading = true;
        this.error = undefined;
        try {
            this.forms = await getActiveRoutingForms({ hostUserId: null });
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    async loadEventTypes() {
        try {
            const eventTypes = await getActiveEventTypes({ hostUserId: null });
            this.eventTypeOptions = eventTypes.map(et => ({ label: et.Name, value: et.Id }));
        } catch (err) {
            this.error = this.extractError(err);
        }
    }

    async loadFormDetail(formId) {
        this.isLoading = true;
        this.error = undefined;
        try {
            this.formDetail = await getRoutingFormDetail({ routingFormId: formId });
            this.editFormName = this.formDetail.name;
            this.editFormDescription = this.formDetail.description || '';
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleNewFormClick() {
        this.newFormName = '';
        this.newFormDescription = '';
        this.showNewFormModal = true;
    }

    handleNewFormNameChange(event) {
        this.newFormName = event.target.value;
    }

    handleNewFormDescriptionChange(event) {
        this.newFormDescription = event.target.value;
    }

    async handleCreateForm() {
        if (!this.newFormName) {
            this.error = 'Form name is required';
            return;
        }

        this.isLoading = true;
        this.error = undefined;
        try {
            const form = await saveRoutingForm({
                formId: null,
                name: this.newFormName,
                description: this.newFormDescription
            });
            this.showNewFormModal = false;
            await this.loadForms();
            await this.loadFormDetail(form.Id);
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleCancelNewForm() {
        this.showNewFormModal = false;
    }

    handleEditFormClick(event) {
        this.loadFormDetail(event.currentTarget.dataset.id);
    }

    handleBackToList() {
        this.formDetail = null;
        this.loadForms();
    }

    handleEditFormNameChange(event) {
        this.editFormName = event.target.value;
    }

    handleEditFormDescriptionChange(event) {
        this.editFormDescription = event.target.value;
    }

    async handleSaveFormDetails() {
        if (!this.editFormName) {
            this.error = 'Form name is required';
            return;
        }

        this.isLoading = true;
        this.error = undefined;
        try {
            await saveRoutingForm({
                formId: this.formDetail.id,
                name: this.editFormName,
                description: this.editFormDescription
            });
            await this.loadFormDetail(this.formDetail.id);
            await this.loadForms();
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleAddFieldClick() {
        this.editingFieldId = null;
        this.fieldName = '';
        this.fieldType = 'Text';
        this.fieldOptions = '';
        this.showFieldModal = true;
    }

    handleEditFieldClick(event) {
        const fieldId = event.currentTarget.dataset.id;
        const field = this.formDetail.fields.find(f => f.id === fieldId);
        if (!field) return;

        this.editingFieldId = field.id;
        this.fieldName = field.name;
        this.fieldType = field.fieldType;
        this.fieldOptions = field.options || '';
        this.showFieldModal = true;
    }

    handleFieldNameChange(event) {
        this.fieldName = event.target.value;
    }

    handleFieldTypeChange(event) {
        this.fieldType = event.detail.value;
    }

    handleFieldOptionsChange(event) {
        this.fieldOptions = event.target.value;
    }

    async handleSaveField() {
        if (!this.fieldName || !this.fieldType) {
            this.error = 'Field name and type are required';
            return;
        }

        this.isLoading = true;
        this.error = undefined;
        try {
            await saveRoutingField({
                fieldId: this.editingFieldId,
                formId: this.formDetail.id,
                name: this.fieldName,
                fieldType: this.fieldType,
                options: this.fieldOptions
            });
            this.showFieldModal = false;
            await this.loadFormDetail(this.formDetail.id);
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleCancelField() {
        this.showFieldModal = false;
    }

    async handleDeleteField(event) {
        this.isLoading = true;
        this.error = undefined;
        try {
            await deleteRoutingField({ fieldId: event.currentTarget.dataset.id });
            await this.loadFormDetail(this.formDetail.id);
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleAddRouteClick() {
        this.editingRouteId = null;
        this.routeTargetEventTypeId = '';
        this.routeConditionFieldId = '';
        this.routeConditionOperator = 'equals';
        this.routeConditionValue = '';
        this.showRouteModal = true;
    }

    handleEditRouteClick(event) {
        const routeId = event.currentTarget.dataset.id;
        const route = this.formDetail.routes.find(r => r.id === routeId);
        if (!route) return;

        this.editingRouteId = route.id;
        this.routeTargetEventTypeId = route.targetEventTypeId;
        this.routeConditionFieldId = route.conditionFieldId || '';
        this.routeConditionOperator = route.conditionOperator || 'equals';
        this.routeConditionValue = route.conditionValue || '';
        this.showRouteModal = true;
    }

    handleRouteTargetChange(event) {
        this.routeTargetEventTypeId = event.detail.value;
    }

    handleRouteConditionFieldChange(event) {
        this.routeConditionFieldId = event.detail.value;
    }

    handleRouteConditionOperatorChange(event) {
        this.routeConditionOperator = event.detail.value;
    }

    handleRouteConditionValueChange(event) {
        this.routeConditionValue = event.target.value;
    }

    async handleSaveRoute() {
        if (!this.routeTargetEventTypeId) {
            this.error = 'Target event type is required';
            return;
        }

        this.isLoading = true;
        this.error = undefined;
        try {
            await saveRoutingRoute({
                routeId: this.editingRouteId,
                formId: this.formDetail.id,
                targetEventTypeId: this.routeTargetEventTypeId,
                conditionFieldId: this.routeConditionFieldId,
                conditionOperator: this.routeConditionOperator,
                conditionValue: this.routeConditionValue
            });
            this.showRouteModal = false;
            await this.loadFormDetail(this.formDetail.id);
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    handleCancelRoute() {
        this.showRouteModal = false;
    }

    async handleDeleteRoute(event) {
        this.isLoading = true;
        this.error = undefined;
        try {
            await deleteRoutingRoute({ routeId: event.currentTarget.dataset.id });
            await this.loadFormDetail(this.formDetail.id);
        } catch (err) {
            this.error = this.extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    get displayRoutes() {
        if (!this.formDetail || !this.formDetail.routes) {
            return [];
        }
        return this.formDetail.routes.map(route => ({
            ...route,
            conditionSummary: this.formatCondition(route)
        }));
    }

    formatCondition(route) {
        if (!route.conditionFieldId) {
            return 'Always';
        }
        const field = this.formDetail.fields.find(f => f.id === route.conditionFieldId);
        const fieldLabel = field ? field.name : route.conditionFieldId;
        const operator = route.conditionOperator || 'equals';
        const value = route.conditionValue || '';
        return `${fieldLabel} ${operator} ${value}`;
    }

    extractError(err) {
        if (err && err.body && err.body.message) return err.body.message;
        if (err && err.message) return err.message;
        return 'An unexpected error occurred';
    }
}
