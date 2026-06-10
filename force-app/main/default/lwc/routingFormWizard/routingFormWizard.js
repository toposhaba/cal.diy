import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getWizardInitData from '@salesforce/apex/RoutingFormWizardController.getWizardInitData';
import getFormForWizard from '@salesforce/apex/RoutingFormWizardController.getFormForWizard';
import saveRoutingFormWizard from '@salesforce/apex/RoutingFormWizardController.saveRoutingFormWizard';

let fieldKeyCounter = 0;

export default class RoutingFormWizard extends NavigationMixin(LightningElement) {
  @track currentView = 'landing';
  @track currentStep = 'basics';
  @track isLoading = false;
  @track error;

  @track existingForms = [];
  @track eventTypeOptions = [];

  formId = null;
  formName = '';
  formDescription = '';
  hostUserId = '';
  hostUserName = '';
  isActive = true;

  @track fields = [];
  @track routes = [];

  editingFieldKey = null;
  fieldDraftName = '';
  fieldDraftType = 'Text';
  fieldDraftOptions = '';
  fieldDraftRequired = true;

  editingRouteIndex = null;
  routeDraftTargetEventTypeId = '';
  routeDraftConditionFieldKey = '';
  routeDraftConditionOperator = 'equals';
  routeDraftConditionValue = '';

  savedFormId = null;
  savedFormName = '';
  savedOwnerUserId = null;

  get steps() {
    return [
      { label: 'Basics', value: 'basics' },
      { label: 'Questions', value: 'questions' },
      { label: 'Routes', value: 'routes' },
      { label: 'Review', value: 'review' }
    ];
  }

  get isLanding() {
    return this.currentView === 'landing';
  }

  get isWizard() {
    return this.currentView === 'wizard';
  }

  get isComplete() {
    return this.currentView === 'complete';
  }

  get isBasicsStep() {
    return this.currentStep === 'basics';
  }

  get isQuestionsStep() {
    return this.currentStep === 'questions';
  }

  get isRoutesStep() {
    return this.currentStep === 'routes';
  }

  get isReviewStep() {
    return this.currentStep === 'review';
  }

  get hasExistingForms() {
    return this.existingForms && this.existingForms.length > 0;
  }

  get hasFields() {
    return this.fields && this.fields.length > 0;
  }

  get hasRoutes() {
    return this.routes && this.routes.length > 0;
  }

  get fieldTypeOptions() {
    return [
      { label: 'Text', value: 'Text' },
      { label: 'Select', value: 'Select' },
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

  get showFieldOptions() {
    return this.fieldDraftType === 'Select';
  }

  get fieldEditorTitle() {
    return this.editingFieldKey ? 'Edit Question' : 'Add Question';
  }

  get routeEditorTitle() {
    return this.editingRouteIndex !== null ? 'Edit Route' : 'Add Route';
  }

  get conditionFieldOptions() {
    return this.fields.map((field) => ({
      label: field.name,
      value: field.clientKey
    }));
  }

  get displayFields() {
    return this.fields.map((field, index) => ({
      ...field,
      index,
      typeLabel: this.fieldTypeOptions.find((opt) => opt.value === field.fieldType)?.label || field.fieldType,
      requiredLabel: field.isRequired ? 'Required' : 'Optional',
      canMoveUp: index > 0,
      canMoveDown: index < this.fields.length - 1
    }));
  }

  get displayRoutes() {
    return this.routes.map((route, index) => ({
      ...route,
      index,
      targetLabel: this.resolveEventTypeName(route.targetEventTypeId),
      conditionSummary: this.formatRouteCondition(route)
    }));
  }

  get reviewFields() {
    return this.displayFields;
  }

  get reviewRoutes() {
    return this.displayRoutes;
  }

  get hostUserFilter() {
    return {
      criteria: [
        {
          fieldPath: 'IsActive',
          operator: 'eq',
          value: true
        }
      ]
    };
  }

  get activeStatusLabel() {
    return this.isActive ? 'Active' : 'Draft (inactive)';
  }

  get publishButtonLabel() {
    return this.isActive ? 'Save & Publish' : 'Save Draft';
  }

  connectedCallback() {
    this.loadInitData();
  }

  async loadInitData() {
    this.isLoading = true;
    this.error = undefined;
    try {
      const data = await getWizardInitData({ hostUserId: null });
      this.existingForms = data.existingForms || [];
      this.eventTypeOptions = (data.eventTypes || []).map((et) => ({
        label: et.name,
        value: et.id
      }));
      if (!this.hostUserId) {
        this.hostUserId = data.currentUserId;
        this.hostUserName = data.currentUserName;
      }
    } catch (err) {
      this.error = this.extractError(err);
    } finally {
      this.isLoading = false;
    }
  }

  handleCreateNew() {
    this.resetWizardState();
    this.currentView = 'wizard';
    this.currentStep = 'basics';
  }

  async handleEditExisting(event) {
    const formId = event.currentTarget.dataset.id;
    this.isLoading = true;
    this.error = undefined;
    try {
      const data = await getFormForWizard({ formId });
      this.formId = data.id;
      this.formName = data.name;
      this.formDescription = data.description || '';
      this.hostUserId = data.ownerUserId;
      this.hostUserName = data.ownerUserName;
      this.isActive = data.isActive;
      this.fields = (data.fields || []).map((field) => ({
        id: field.id,
        clientKey: field.clientKey,
        name: field.name,
        fieldType: field.fieldType,
        options: field.options || '',
        isRequired: field.isRequired
      }));
      this.routes = (data.routes || []).map((route) => ({
        id: route.id,
        targetEventTypeId: route.targetEventTypeId,
        conditionFieldKey: route.conditionFieldId || '',
        conditionOperator: route.conditionOperator || 'equals',
        conditionValue: route.conditionValue || ''
      }));
      this.currentView = 'wizard';
      this.currentStep = 'basics';
    } catch (err) {
      this.error = this.extractError(err);
    } finally {
      this.isLoading = false;
    }
  }

  resetWizardState() {
    this.formId = null;
    this.formName = '';
    this.formDescription = '';
    this.isActive = true;
    this.fields = [];
    this.routes = [];
    this.clearFieldEditor();
    this.clearRouteEditor();
    fieldKeyCounter = 0;
  }

  handleFormNameChange(event) {
    this.formName = event.target.value;
  }

  handleFormDescriptionChange(event) {
    this.formDescription = event.target.value;
  }

  async handleHostUserChange(event) {
    this.hostUserId = event.detail.recordId;
    if (this.hostUserId) {
      try {
        const data = await getWizardInitData({ hostUserId: this.hostUserId });
        this.eventTypeOptions = (data.eventTypes || []).map((et) => ({
          label: et.name,
          value: et.id
        }));
      } catch (err) {
        this.error = this.extractError(err);
      }
    }
  }

  handleActiveChange(event) {
    this.isActive = event.target.checked;
  }

  handleNextFromBasics() {
    if (!this.formName || !this.formName.trim()) {
      this.error = 'Form name is required';
      return;
    }
    if (!this.hostUserId) {
      this.error = 'Host user is required';
      return;
    }
    this.error = undefined;
    this.currentStep = 'questions';
  }

  handleBackToBasics() {
    this.error = undefined;
    this.currentStep = 'basics';
  }

  handleNextFromQuestions() {
    if (!this.hasFields) {
      this.error = 'Add at least one question before continuing';
      return;
    }
    this.error = undefined;
    this.currentStep = 'routes';
  }

  handleBackToQuestions() {
    this.error = undefined;
    this.currentStep = 'questions';
  }

  handleNextFromRoutes() {
    if (!this.hasRoutes) {
      this.error = 'Add at least one route before continuing';
      return;
    }
    this.error = undefined;
    this.currentStep = 'review';
  }

  handleBackToRoutes() {
    this.error = undefined;
    this.currentStep = 'routes';
  }

  handleBackToLanding() {
    this.error = undefined;
    this.currentView = 'landing';
    this.loadInitData();
  }

  handleAddFieldClick() {
    this.editingFieldKey = null;
    this.fieldDraftName = '';
    this.fieldDraftType = 'Text';
    this.fieldDraftOptions = '';
    this.fieldDraftRequired = true;
  }

  handleEditFieldClick(event) {
    const clientKey = event.currentTarget.dataset.key;
    const field = this.fields.find((f) => f.clientKey === clientKey);
    if (!field) return;
    this.editingFieldKey = clientKey;
    this.fieldDraftName = field.name;
    this.fieldDraftType = field.fieldType;
    this.fieldDraftOptions = field.options || '';
    this.fieldDraftRequired = field.isRequired;
  }

  handleFieldDraftNameChange(event) {
    this.fieldDraftName = event.target.value;
  }

  handleFieldDraftTypeChange(event) {
    this.fieldDraftType = event.detail.value;
  }

  handleFieldDraftOptionsChange(event) {
    this.fieldDraftOptions = event.target.value;
  }

  handleFieldDraftRequiredChange(event) {
    this.fieldDraftRequired = event.target.checked;
  }

  handleSaveFieldDraft() {
    if (!this.fieldDraftName || !this.fieldDraftName.trim()) {
      this.error = 'Question text is required';
      return;
    }
    if (this.fieldDraftType === 'Select' && !this.fieldDraftOptions.trim()) {
      this.error = 'Select questions need at least one option';
      return;
    }

    if (this.editingFieldKey) {
      this.fields = this.fields.map((field) =>
        field.clientKey === this.editingFieldKey
          ? {
              ...field,
              name: this.fieldDraftName.trim(),
              fieldType: this.fieldDraftType,
              options: this.fieldDraftOptions,
              isRequired: this.fieldDraftRequired
            }
          : field
      );
    } else {
      fieldKeyCounter += 1;
      this.fields = [
        ...this.fields,
        {
          id: null,
          clientKey: `field-${fieldKeyCounter}`,
          name: this.fieldDraftName.trim(),
          fieldType: this.fieldDraftType,
          options: this.fieldDraftOptions,
          isRequired: this.fieldDraftRequired
        }
      ];
    }

    this.error = undefined;
    this.clearFieldEditor();
  }

  handleCancelFieldDraft() {
    this.clearFieldEditor();
  }

  handleDeleteField(event) {
    const clientKey = event.currentTarget.dataset.key;
    this.fields = this.fields.filter((field) => field.clientKey !== clientKey);
    this.routes = this.routes.map((route) =>
      route.conditionFieldKey === clientKey
        ? { ...route, conditionFieldKey: '', conditionValue: '' }
        : route
    );
  }

  handleMoveFieldUp(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10);
    if (index <= 0) return;
    const updated = [...this.fields];
    [updated[index - 1], updated[index]] = [updated[index], updated[index - 1]];
    this.fields = updated;
  }

  handleMoveFieldDown(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10);
    if (index >= this.fields.length - 1) return;
    const updated = [...this.fields];
    [updated[index], updated[index + 1]] = [updated[index + 1], updated[index]];
    this.fields = updated;
  }

  handleAddRouteClick() {
    this.editingRouteIndex = null;
    this.routeDraftTargetEventTypeId = '';
    this.routeDraftConditionFieldKey = '';
    this.routeDraftConditionOperator = 'equals';
    this.routeDraftConditionValue = '';
  }

  handleEditRouteClick(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10);
    const route = this.routes[index];
    if (!route) return;
    this.editingRouteIndex = index;
    this.routeDraftTargetEventTypeId = route.targetEventTypeId;
    this.routeDraftConditionFieldKey = route.conditionFieldKey || '';
    this.routeDraftConditionOperator = route.conditionOperator || 'equals';
    this.routeDraftConditionValue = route.conditionValue || '';
  }

  handleRouteTargetChange(event) {
    this.routeDraftTargetEventTypeId = event.detail.value;
  }

  handleRouteConditionFieldChange(event) {
    this.routeDraftConditionFieldKey = event.detail.value;
  }

  handleRouteConditionOperatorChange(event) {
    this.routeDraftConditionOperator = event.detail.value;
  }

  handleRouteConditionValueChange(event) {
    this.routeDraftConditionValue = event.target.value;
  }

  handleSaveRouteDraft() {
    if (!this.routeDraftTargetEventTypeId) {
      this.error = 'Target event type is required';
      return;
    }

    const routeData = {
      id: null,
      targetEventTypeId: this.routeDraftTargetEventTypeId,
      conditionFieldKey: this.routeDraftConditionFieldKey || '',
      conditionOperator: this.routeDraftConditionOperator,
      conditionValue: this.routeDraftConditionValue
    };

    if (this.editingRouteIndex !== null) {
      this.routes = this.routes.map((route, index) =>
        index === this.editingRouteIndex ? { ...route, ...routeData, id: route.id } : route
      );
    } else {
      this.routes = [...this.routes, routeData];
    }

    this.error = undefined;
    this.clearRouteEditor();
  }

  handleCancelRouteDraft() {
    this.clearRouteEditor();
  }

  handleDeleteRoute(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10);
    this.routes = this.routes.filter((_, i) => i !== index);
  }

  async handlePublish() {
    this.isLoading = true;
    this.error = undefined;
    try {
      const fieldInputs = this.fields.map((field, index) => ({
        clientKey: field.clientKey,
        fieldId: field.id,
        name: field.name,
        fieldType: field.fieldType,
        options: field.options,
        isRequired: field.isRequired,
        sortOrder: index
      }));

      const routeInputs = this.routes.map((route) => {
        const conditionKey = route.conditionFieldKey || '';
        const isSalesforceId = /^[a-zA-Z0-9]{15,18}$/.test(conditionKey);
        return {
          routeId: route.id,
          targetEventTypeId: route.targetEventTypeId,
          conditionFieldId: isSalesforceId ? conditionKey : null,
          conditionClientKey: !isSalesforceId && conditionKey ? conditionKey : null,
          conditionOperator: route.conditionOperator,
          conditionValue: route.conditionValue
        };
      });

      const result = await saveRoutingFormWizard({
        formId: this.formId,
        name: this.formName.trim(),
        description: this.formDescription,
        ownerUserId: this.hostUserId,
        isActive: this.isActive,
        fields: fieldInputs,
        routes: routeInputs
      });

      this.savedFormId = result.formId;
      this.savedFormName = result.formName;
      this.savedOwnerUserId = result.ownerUserId;
      this.currentView = 'complete';
    } catch (err) {
      this.error = this.extractError(err);
    } finally {
      this.isLoading = false;
    }
  }

  handleOpenRoutingBooking() {
    this[NavigationMixin.Navigate]({
      type: 'standard__navItemPage',
      attributes: { apiName: 'Routing_Booking' }
    });
  }

  handleOpenAdvancedBuilder() {
    this[NavigationMixin.Navigate]({
      type: 'standard__navItemPage',
      attributes: { apiName: 'routingFormAdvanced' }
    });
  }

  handleCreateAnother() {
    this.resetWizardState();
    this.currentView = 'wizard';
    this.currentStep = 'basics';
    this.loadInitData();
  }

  clearFieldEditor() {
    this.editingFieldKey = null;
    this.fieldDraftName = '';
    this.fieldDraftType = 'Text';
    this.fieldDraftOptions = '';
    this.fieldDraftRequired = true;
  }

  clearRouteEditor() {
    this.editingRouteIndex = null;
    this.routeDraftTargetEventTypeId = '';
    this.routeDraftConditionFieldKey = '';
    this.routeDraftConditionOperator = 'equals';
    this.routeDraftConditionValue = '';
  }

  resolveEventTypeName(eventTypeId) {
    const match = this.eventTypeOptions.find((opt) => opt.value === eventTypeId);
    return match ? match.label : eventTypeId;
  }

  formatRouteCondition(route) {
    if (!route.conditionFieldKey) {
      return 'Always (default route)';
    }
    const field = this.fields.find(
      (f) => f.clientKey === route.conditionFieldKey || f.id === route.conditionFieldKey
    );
    const fieldLabel = field ? field.name : route.conditionFieldKey;
    return `${fieldLabel} ${route.conditionOperator} ${route.conditionValue || ''}`.trim();
  }

  extractError(err) {
    if (err && err.body && err.body.message) return err.body.message;
    if (err && err.message) return err.message;
    return 'An unexpected error occurred';
  }
}