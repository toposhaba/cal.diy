## What does this PR do?

<!-- Summary of changes and which issue is addressed -->

- Fixes #XXXX

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Refactoring
- [ ] Configuration change

## Salesforce Deployment Checklist

- [ ] All Apex classes use `with sharing`
- [ ] All SOQL queries use `WITH USER_MODE`
- [ ] All DML uses `as user` syntax
- [ ] No hardcoded IDs or credentials
- [ ] Test coverage is 75%+ for affected classes
- [ ] Permission sets updated if new fields/objects added

## How should this be tested?

<!-- Steps to reproduce and verify the change -->

1. Deploy: `sf project deploy start --source-dir force-app`
2. Run tests: `sf apex run test --test-level RunLocalTests`
3. ...

## Test Results

- [ ] All existing tests pass
- [ ] New tests added for new functionality
