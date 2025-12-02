# Production-Grade Refactoring Plan

## Overview
This document outlines the comprehensive refactoring of the Ansible playbook to make it production-grade for Red Hat-based environments.

## Objectives

### 1. Repeatability & Idempotence
- Replace all `shell:` and `command:` calls with native Ansible modules
- Use `creates:` or `changed_when:` for idempotent operations
- Ensure every task can safely re-run

### 2. Environment Parameterization
- Extract all hardcoded values to variables
- Organize variables by role and environment
- Centralize version management

### 3. Structure and Maintainability
- Ensure roles are properly structured (already done)
- Add comprehensive tags
- Add descriptive comments

### 4. Robustness & Validation
- Add pre-flight checks (OS version, disk space, RAM)
- Validate variable presence
- Use block/rescue for critical operations

### 5. Version-Controlled Parameters
- Centralize all versions in `vars/release.yml` or `defaults/main.yml`
- Make upgrades a single-file change

## Refactoring Priority

### Phase 1: Critical Infrastructure (High Priority)
1. **PostgreSQL** - Database is critical, hardcoded versions
2. **Java Installation** - Used by multiple services, hardcoded paths
3. **Common/System Prep** - Foundation for all roles

### Phase 2: Application Services (Medium Priority)
4. **DMC** - Core application
5. **MMG** - Core application
6. **SLS** - Core service

### Phase 3: Supporting Services (Lower Priority)
7. **Elasticsearch/OpenSearch**
8. **Logstash**
9. **Kibana/OpenSearch Dashboards**
10. **Zabbix**
11. **HAProxy**

## Variable Structure

```
vars/
  release.yml          # All version numbers
  env/
    opt_nc.yml         # Customer-specific overrides
    default.yml        # Default environment values
group_vars/
  all.yml             # Global defaults
roles/
  <role>/
    defaults/
      main.yml        # Role-specific defaults
    vars/
      main.yml        # Role-specific variables (if needed)
```

## Implementation Strategy

1. Create centralized variable files
2. Refactor one role at a time
3. Test idempotency after each refactoring
4. Document changes in role-specific README

