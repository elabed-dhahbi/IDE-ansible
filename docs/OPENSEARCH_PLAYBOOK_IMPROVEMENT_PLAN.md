# OpenSearch Playbook - Production-Ready Improvement Plan
**Senior SRE Review & Implementation Plan**

## Executive Summary

This document outlines a comprehensive plan to transform the OpenSearch Ansible playbook into a production-ready, idempotent, and fully portable solution. The plan addresses critical issues in idempotency, portability, logic flaws, and dynamic configuration management.

---

## Phase 1: Critical Idempotency Fixes

### 1.1 Service Management Idempotency

**Current Issue:**
- Service stop fails if service not running (Line 27-31)
- Multiple restarts (4+) in single playbook run
- No conditional checks before operations

**Solution:**
```yaml
# Replace with idempotent service management
- name: Check if OpenSearch service is running
  systemd:
    name: "{{ opensearch_service_name }}"
  register: opensearch_service_status
  become: yes
  changed_when: false

- name: Stop OpenSearch service before certificate changes
  systemd:
    name: "{{ opensearch_service_name }}"
    state: stopped
  become: yes
  when: opensearch_service_status.status.ActiveState == "active"
  ignore_errors: yes
```

**Implementation:**
- Add service state checks before all service operations
- Use handlers for restarts (batch all changes, restart once)
- Add `changed_when: false` for read-only operations

---

### 1.2 Certificate Generation Idempotency

**Current Issue:**
- Uses `creates` but doesn't validate certificate validity
- No expiration checking
- Temporary files not cleaned up
- Certificates regenerated even if valid

**Solution:**
```yaml
- name: Check certificate expiration
  shell: |
    openssl x509 -in {{ opensearch_config_dir }}/security/{{ item }} -noout -checkend {{ opensearch_cert_min_validity_seconds }}
  args:
    executable: /bin/bash
  register: cert_check
  failed_when: false
  changed_when: false
  loop:
    - root-ca.pem
    - esnode.pem
    - admin.pem

- name: Generate certificates only if expired or missing
  # ... certificate generation tasks ...
  when: cert_check.results | selectattr('rc', 'equalto', 1) | list | length > 0
```

**Implementation:**
- Add certificate validation before generation
- Check expiration (regenerate if < 30 days remaining)
- Clean up temporary files (admin-key-temp.pem, CSRs)
- Use conditional generation based on validation

---

### 1.3 Configuration File Idempotency

**Current Issue:**
- Using `lineinfile` in loops (inefficient, can cause formatting issues)
- Duplicate configuration entries possible
- No validation of final configuration

**Solution:**
```yaml
# Replace lineinfile loops with template approach
- name: Generate OpenSearch configuration from template
  template:
    src: opensearch.yml.j2
    dest: "{{ opensearch_config_dir }}/opensearch.yml"
    owner: "{{ opensearch_user }}"
    group: "{{ opensearch_group }}"
    mode: '0644'
    backup: yes
  become: yes
  notify: restart opensearch
```

**Implementation:**
- Create Jinja2 templates for `opensearch.yml` and `jvm.options`
- Use `template` module instead of `lineinfile` loops
- Add configuration validation after generation
- Use handlers for service restarts

---

### 1.4 Password Hash Generation Idempotency

**Current Issue:**
- Password hash generated every run
- No check if password changed
- Hash stored in fact, not persisted

**Solution:**
```yaml
- name: Check if password hash needs regeneration
  stat:
    path: "{{ opensearch_config_dir }}/opensearch-security/.password_hash"
  register: password_hash_file

- name: Read existing password hash
  slurp:
    src: "{{ opensearch_config_dir }}/opensearch-security/.password_hash"
  register: existing_hash
  when: password_hash_file.stat.exists

- name: Generate password hash only if needed
  shell: |
    cd /usr/share/opensearch/plugins/opensearch-security/tools
    OPENSEARCH_JAVA_HOME={{ opensearch_java_home }} ./hash.sh -p "{{ opensearch_config.admin_password }}"
  register: opensearch_password_hash_result
  when: >
    not password_hash_file.stat.exists or
    existing_hash.content | b64decode | string != opensearch_config.admin_password
  become: yes
```

**Implementation:**
- Store password hash in file
- Compare before regenerating
- Only regenerate if password changed

---

## Phase 2: Portability & Dynamic Configuration

### 2.1 Remove All Hardcoded Values

**Current Issues:**
- Hardcoded certificate paths (Lines 169-177)
- Hardcoded certificate validity (3650, 730 days)
- Hardcoded certificate subjects (C, ST, L, O, OU, CN)
- Hardcoded organization info

**Solution:**
Add to `defaults/main.yml`:
```yaml
# Certificate configuration
opensearch_certificates:
  security_dir: "{{ opensearch_config_dir }}/security"
  root_ca:
    validity_days: "{{ opensearch_cert_validity.root_ca | default(3650) }}"
    key_size: "{{ opensearch_cert_key_size.root_ca | default(4096) }}"
    subject:
      C: "{{ certificate_org.country | default('US') }}"
      ST: "{{ certificate_org.state | default('CA') }}"
      L: "{{ certificate_org.city | default('San Francisco') }}"
      O: "{{ certificate_org.organization | default('SICAP') }}"
      OU: "{{ certificate_org.organizational_unit | default('IT Department') }}"
      CN: "{{ certificate_org.root_ca_cn | default('opensearch-ca') }}"
  admin:
    validity_days: "{{ opensearch_cert_validity.admin | default(730) }}"
    key_size: "{{ opensearch_cert_key_size.admin | default(2048) }}"
    subject:
      C: "{{ certificate_org.country | default('CA') }}"
      ST: "{{ certificate_org.state | default('ONTARIO') }}"
      L: "{{ certificate_org.city | default('TORONTO') }}"
      O: "{{ certificate_org.organization | default('ORG') }}"
      OU: "{{ certificate_org.organizational_unit | default('UNIT') }}"
      CN: "{{ certificate_org.admin_cn | default('A') }}"
  node:
    validity_days: "{{ opensearch_cert_validity.node | default(3650) }}"
    key_size: "{{ opensearch_cert_key_size.node | default(4096) }}"
    subject:
      C: "{{ certificate_org.country | default('US') }}"
      ST: "{{ certificate_org.state | default('CA') }}"
      L: "{{ certificate_org.city | default('San Francisco') }}"
      O: "{{ certificate_org.organization | default('SICAP') }}"
      OU: "{{ certificate_org.organizational_unit | default('IT Department') }}"
      CN: "{{ ansible_hostname }}"
```

**Add to `config/values.yaml`:**
```yaml
# Certificate Organization Information
certificate_org:
  country: "US"
  state: "CA"
  city: "San Francisco"
  organization: "SICAP"
  organizational_unit: "IT Department"
  root_ca_cn: "opensearch-ca"
  admin_cn: "A"

# Certificate Validity Periods (days)
opensearch_cert_validity:
  root_ca: 3650
  admin: 730
  node: 3650

# Certificate Key Sizes (bits)
opensearch_cert_key_size:
  root_ca: 4096
  admin: 2048
  node: 4096
```

**Implementation:**
- Replace all hardcoded paths with variables
- Replace all hardcoded certificate subjects with variables
- Replace all hardcoded validity periods with variables
- Make certificate subjects environment-aware

---

### 2.2 Dynamic Package Version Management

**Current Issue:**
- OpenSearch version hardcoded in defaults
- No auto-detection like `sync_packages.sh`

**Solution:**
Enhance `scripts/sync_packages.sh` to also handle OpenSearch:
```bash
# Add to sync_packages.sh
opensearch_file=$(find "$OFFLINE_DIR" -maxdepth 1 -type f -name "opensearch-*-linux-x64.rpm" ! -name "*dashboards*" 2>/dev/null | sort -V | tail -1)
if [[ -n "$opensearch_file" ]]; then
    version=$(extract_version "opensearch-([0-9]+\.[0-9]+\.[0-9]+)-" "$(basename "$opensearch_file")")
    if [[ -n "$version" ]]; then
        detected_versions["opensearch"]="$version"
        echo -e "${GREEN}✓ Detected OpenSearch version: $version${NC}"
    fi
fi
```

**Implementation:**
- Ensure `sync_packages.sh` detects OpenSearch version
- Playbook uses `{{ versions.opensearch }}` from values.yaml
- Version auto-updates when new packages added

---

### 2.3 Environment-Aware Configuration

**Current Issue:**
- No environment detection
- Same config for dev/staging/prod

**Solution:**
Add environment variables to `config/values.yaml`:
```yaml
# Environment Configuration
environment:
  name: "{{ env_name | default('production') }}"  # dev, staging, production
  certificate_renewal_days: "{{ env_cert_renewal_days | default(30) }}"
  
# Environment-specific overrides
environments:
  dev:
    opensearch_cert_validity:
      root_ca: 365
      admin: 90
      node: 365
    opensearch_jvm:
      heap_size: "1g"
  staging:
    opensearch_cert_validity:
      root_ca: 730
      admin: 180
      node: 730
    opensearch_jvm:
      heap_size: "2g"
  production:
    opensearch_cert_validity:
      root_ca: 3650
      admin: 730
      node: 3650
    opensearch_jvm:
      heap_size: "4g"
```

**Implementation:**
- Add environment detection
- Apply environment-specific overrides
- Use environment-aware defaults

---

## Phase 3: Logic Flaw Fixes

### 3.1 Fix Service Stop Logic

**Current Issue:**
- Stops service unconditionally
- No check if certificates actually need regeneration

**Solution:**
```yaml
- name: Determine if certificate regeneration is needed
  set_fact:
    certs_need_regeneration: >
      {{ cert_check.results | selectattr('rc', 'equalto', 1) | list | length > 0 }}

- name: Stop OpenSearch service only if certificates need regeneration
  systemd:
    name: "{{ opensearch_service_name }}"
    state: stopped
  become: yes
  when: certs_need_regeneration
  ignore_errors: yes
```

---

### 3.2 Fix Multiple Restart Issue

**Current Issue:**
- 4+ restarts in one playbook run
- Causes unnecessary downtime

**Solution:**
Use handlers:
```yaml
# handlers/main.yml
---
- name: restart opensearch
  systemd:
    name: "{{ opensearch_service_name }}"
    state: restarted
    daemon_reload: yes
  become: yes

# In tasks, use notify instead of direct restart
- name: Configure OpenSearch security
  template:
    src: opensearch.yml.j2
    dest: "{{ opensearch_config_dir }}/opensearch.yml"
  notify: restart opensearch
```

---

### 3.3 Fix Certificate Cleanup Logic

**Current Issue:**
- Removes security directory before creating it
- Doesn't clean up temporary files
- Admin CSR not cleaned

**Solution:**
```yaml
- name: Clean up temporary certificate files
  file:
    path: "{{ item }}"
    state: absent
  loop:
    - "{{ opensearch_config_dir }}/security/admin-key-temp.pem"
    - "{{ opensearch_config_dir }}/security/admin.csr"
    - "{{ opensearch_config_dir }}/security/esnode.csr"
  become: yes
  tags: [opensearch, config, security, certificates, cleanup]
```

---

### 3.4 Fix Configuration Duplication

**Current Issue:**
- Disk watermark settings configured twice (Lines 195-198, 362-365)
- Performance settings overlap

**Solution:**
- Consolidate all configuration into single template
- Remove duplicate entries
- Use single source of truth

---

## Phase 4: Production Readiness

### 4.1 Add Variable Validation

**Solution:**
```yaml
- name: Validate required variables
  assert:
    that:
      - opensearch_config_dir is defined
      - opensearch_config.admin_password is defined
      - opensearch_config.cluster_name is defined
      - opensearch_user is defined
      - opensearch_group is defined
    fail_msg: "Required OpenSearch variables are not defined"
    success_msg: "All required variables are defined"
  tags: [opensearch, validation]
```

---

### 4.2 Add Pre-flight Checks

**Solution:**
```yaml
- name: Check OpenSSL is installed
  command: which openssl
  register: openssl_check
  changed_when: false
  failed_when: openssl_check.rc != 0

- name: Check required directories exist
  stat:
    path: "{{ item }}"
  register: dir_check
  loop:
    - "{{ opensearch_config_dir }}"
    - "{{ opensearch_data_dir }}"
    - "{{ opensearch_logs_dir }}"
  failed_when: not dir_check.results | selectattr('stat.exists', 'equalto', true) | list | length == 3
```

---

### 4.3 Add Error Handling

**Solution:**
```yaml
- name: Generate certificates with error handling
  block:
    - name: Generate Root CA
      # ... certificate generation ...
  rescue:
    - name: Clean up on failure
      file:
        path: "{{ opensearch_config_dir }}/security"
        state: absent
      become: yes
    - name: Fail with message
      fail:
        msg: "Certificate generation failed. Check OpenSSL installation and permissions."
```

---

### 4.4 Add Configuration Backup

**Solution:**
```yaml
- name: Backup existing configuration
  copy:
    src: "{{ opensearch_config_dir }}/opensearch.yml"
    dest: "{{ opensearch_config_dir }}/opensearch.yml.backup-{{ ansible_date_time.epoch }}"
    remote_src: yes
  become: yes
  when: opensearch_config_backup | default(true)
  failed_when: false
  changed_when: false
```

---

### 4.5 Add Health Checks

**Solution:**
```yaml
- name: Verify OpenSearch is healthy after configuration
  uri:
    url: "https://{{ ansible_host }}:{{ opensearch_config.http_port }}/_cluster/health"
    method: GET
    user: "admin"
    password: "{{ opensearch_config.admin_password }}"
    force_basic_auth: yes
    validate_certs: false
    status_code: [200]
  register: health_check
  retries: 10
  delay: 5
  until: health_check.json.status in ['green', 'yellow']
  failed_when: health_check.json.status == 'red'
```

---

## Phase 5: Template-Based Configuration

### 5.1 Create Jinja2 Templates

**Create `templates/opensearch.yml.j2`:**
```yaml
# OpenSearch Configuration
# Generated by Ansible - DO NOT EDIT MANUALLY

cluster.name: {{ opensearch_config.cluster_name }}
node.name: {{ opensearch_config.node_name }}
node.roles: [ data, ingest, cluster_manager ]

network.host: {{ opensearch_config.network_host }}
http.port: {{ opensearch_config.http_port }}
transport.port: {{ opensearch_config.transport_port }}

discovery.type: {{ opensearch_config.discovery_type }}

bootstrap.memory_lock: {{ opensearch_config.bootstrap_memory_lock | lower }}

path.data: {{ opensearch_config.path_data }}
path.logs: {{ opensearch_config.path_logs }}
path.repo: ["{{ opensearch_config.path_repo }}"]

# Security Configuration
plugins.security.disabled: false
plugins.security.ssl.transport.enabled: true
plugins.security.ssl.transport.pemcert_filepath: {{ opensearch_certificates.security_dir }}/esnode.pem
plugins.security.ssl.transport.pemkey_filepath: {{ opensearch_certificates.security_dir }}/esnode-key.pem
plugins.security.ssl.transport.pemtrustedcas_filepath: {{ opensearch_certificates.security_dir }}/root-ca.pem
plugins.security.ssl.transport.enforce_hostname_verification: false

plugins.security.ssl.http.enabled: true
plugins.security.ssl.http.pemcert_filepath: {{ opensearch_certificates.security_dir }}/esnode.pem
plugins.security.ssl.http.pemkey_filepath: {{ opensearch_certificates.security_dir }}/esnode-key.pem
plugins.security.ssl.http.pemtrustedcas_filepath: {{ opensearch_certificates.security_dir }}/root-ca.pem

plugins.security.allow_unsafe_democertificates: false
plugins.security.allow_default_init_securityindex: true
plugins.security.authcz.admin_dn: ['CN={{ opensearch_certificates.admin.subject.CN }},OU={{ opensearch_certificates.admin.subject.OU }},O={{ opensearch_certificates.admin.subject.O }},L={{ opensearch_certificates.admin.subject.L }},ST={{ opensearch_certificates.admin.subject.ST }},C={{ opensearch_certificates.admin.subject.C }}']
plugins.security.nodes_dn: ['CN={{ ansible_hostname }},OU={{ opensearch_certificates.node.subject.OU }},O={{ opensearch_certificates.node.subject.O }},L={{ opensearch_certificates.node.subject.L }},ST={{ opensearch_certificates.node.subject.ST }},C={{ opensearch_certificates.node.subject.C }}']

# Performance Settings
indices.memory.index_buffer_size: {{ opensearch_config.indices_memory_index_buffer_size }}
indices.queries.cache.size: {{ opensearch_config.indices_queries_cache_size }}
indices.fielddata.cache.size: {{ opensearch_config.indices_fielddata_cache_size }}

# Cluster Settings
cluster.routing.allocation.disk.threshold_enabled: {{ opensearch_config.cluster_routing_allocation_disk_threshold_enabled | lower }}
cluster.routing.allocation.disk.watermark.low: {{ opensearch_config.cluster_routing_allocation_disk_watermark_low }}
cluster.routing.allocation.disk.watermark.high: {{ opensearch_config.cluster_routing_allocation_disk_watermark_high }}
cluster.routing.allocation.disk.watermark.flood_stage: {{ opensearch_config.cluster_routing_allocation_disk_watermark_flood_stage }}

node.max_local_storage_nodes: 3
```

---

## Implementation Roadmap

### Week 1: Foundation
- [ ] Phase 1.1: Service management idempotency
- [ ] Phase 1.2: Certificate validation
- [ ] Phase 2.1: Remove hardcoded values (paths, subjects)
- [ ] Add variable validation (Phase 4.1)

### Week 2: Core Improvements
- [ ] Phase 1.3: Template-based configuration
- [ ] Phase 1.4: Password hash idempotency
- [ ] Phase 3.1-3.4: Fix all logic flaws
- [ ] Phase 4.2: Pre-flight checks

### Week 3: Production Hardening
- [ ] Phase 3.2: Handler-based restarts
- [ ] Phase 4.3: Error handling
- [ ] Phase 4.4: Configuration backup
- [ ] Phase 4.5: Health checks

### Week 4: Testing & Documentation
- [ ] Test idempotency (run playbook 3x, verify no changes on 2nd/3rd)
- [ ] Test portability (different environments)
- [ ] Test certificate regeneration
- [ ] Update documentation
- [ ] Create migration guide

---

## Success Criteria

✅ **Idempotency:**
- Playbook can run multiple times without errors
- No unnecessary service restarts
- No certificate regeneration if valid
- No configuration changes if already correct

✅ **Portability:**
- No hardcoded values
- Works across dev/staging/prod
- Environment-aware configuration
- Dynamic version detection

✅ **Production Ready:**
- Comprehensive error handling
- Pre-flight validation
- Health checks
- Configuration backup
- Proper logging

✅ **Maintainability:**
- Template-based configuration
- Clear variable structure
- Well-documented
- Easy to extend

---

## Risk Mitigation

1. **Backup Strategy:** Always backup before changes
2. **Rollback Plan:** Git commits at each phase
3. **Testing:** Test in dev environment first
4. **Gradual Rollout:** Implement phase by phase
5. **Monitoring:** Enhanced logging and health checks

---

## Next Steps

1. Review and approve this plan
2. Create feature branch: `git checkout -b feature/opensearch-production-ready`
3. Implement Phase 1 (Critical Idempotency)
4. Test thoroughly
5. Merge to main after validation

---

**Document Version:** 1.0  
**Last Updated:** 2025-12-02  
**Author:** Senior SRE Team  
**Status:** Ready for Implementation

