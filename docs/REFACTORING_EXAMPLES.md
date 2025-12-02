# Production-Grade Refactoring Examples

This document shows before/after examples of the refactoring work done to make the playbook production-ready.

## Example 1: PostgreSQL Package Installation

### ❌ Before (Non-Idempotent, Hardcoded)
```yaml
- name: Install PostgreSQL packages in correct order
  command: rpm -Uvh --force "{{ paths.offline_dir }}/{{ item }}"
  loop:
    - "postgresql15-libs-15.14-1PGDG.rhel9.x86_64.rpm"
    - "postgresql15-15.14-1PGDG.rhel9.x86_64.rpm"
    - "postgresql15-server-15.14-1PGDG.rhel9.x86_64.rpm"
    - "postgresql15-contrib-15.14-1PGDG.rhel9.x86_64.rpm"
    - "libpq5-17.6-1PGDG.rhel9.x86_64.rpm"
    - "python3-psycopg2-2.8.6-6.el9.x86_64.rpm"
  become: yes
```

**Problems:**
- Uses `command:` instead of native module (not idempotent)
- Hardcoded version numbers (15.14-1PGDG.rhel9)
- Hardcoded package names
- No validation
- Will fail if packages already installed

### ✅ After (Idempotent, Parameterized)
```yaml
# Define packages using variables from vars/release.yml
- name: Define PostgreSQL package installation order
  set_fact:
    postgresql_package_list:
      - name: "postgresql{{ postgresql_major_version }}-libs"
        file_pattern: "postgresql{{ postgresql_major_version }}-libs-{{ postgresql_package_version }}.x86_64.rpm"
      - name: "postgresql{{ postgresql_major_version }}"
        file_pattern: "postgresql{{ postgresql_major_version }}-{{ postgresql_package_version }}.x86_64.rpm"
      # ... more packages

# Install using native yum module (idempotent)
- name: Install PostgreSQL packages in correct order
  yum:
    name: "{{ paths.offline_dir }}/{{ item.file_pattern }}"
    state: present
    disable_gpg_check: yes
  loop: "{{ postgresql_package_list }}"
  become: yes
```

**Improvements:**
- ✅ Uses native `yum` module (idempotent - checks if already installed)
- ✅ All versions from `vars/release.yml` (single source of truth)
- ✅ Package names constructed from variables
- ✅ Can safely re-run without errors
- ✅ Includes validation blocks

---

## Example 2: Java Installation

### ❌ Before (Hardcoded Paths and Versions)
```yaml
- name: Find Java 1.8.0_92 package
  find:
    paths: "{{ paths.offline_dir }}"
    patterns: "1_8_0_92-jdk.tar.gz"
  register: java_package_files

- name: Extract JDK8 package
  unarchive:
    src: "{{ item.path }}"
    dest: "/usr/j2se"  # Hardcoded path
    remote_src: yes
  loop: "{{ java_package_files.files }}"
  become: yes

- name: Find extracted Java directory
  find:
    paths: "/usr/j2se"  # Hardcoded path
    patterns: "1_8_0_92-jdk"  # Hardcoded version
    file_type: directory
  register: java_directories
```

**Problems:**
- Hardcoded installation path (`/usr/j2se`)
- Hardcoded version pattern (`1_8_0_92-jdk`)
- No idempotence check (will re-extract every time)
- Not portable across environments

### ✅ After (Parameterized, Idempotent)
```yaml
# Validate variables first
- name: Validate Java installation variables
  assert:
    that:
      - java_install_dir is defined
      - java_legacy_version is defined
    fail_msg: "Required Java variables not defined"
  tags: [dmc, java, install, validation, always]

# Check if already installed (idempotence)
- name: Check if Java is already installed
  stat:
    path: "{{ java_install_dir }}/current/bin/java"
  register: java_installed

# Only extract if not installed
- name: Extract JDK8 package (only if not already installed)
  unarchive:
    src: "{{ java_package_files.files[0].path }}"
    dest: "{{ java_install_dir }}"  # From vars/env/default.yml
    remote_src: yes
  when: not java_installed.stat.exists  # Idempotence check
  become: yes

- name: Find extracted Java directory
  find:
    paths: "{{ java_install_dir }}"  # Variable-based path
    patterns:
      - "{{ java_legacy_version }}-jdk"  # From vars/release.yml
      - "jdk{{ java_full_version }}*"
    file_type: directory
  register: java_directories
  when: not java_installed.stat.exists
```

**Improvements:**
- ✅ All paths from variables (`java_install_dir` from `vars/env/default.yml`)
- ✅ All versions from `vars/release.yml`
- ✅ Idempotence check (skips if already installed)
- ✅ Portable across environments
- ✅ Validation before execution

---

## Example 3: Package Installation with Dependencies

### ❌ Before (No Validation)
```yaml
- name: Install PostgreSQL dependencies
  dnf:
    name:
      - perl
      - perl-libs
      - libxslt
      - libxslt-devel
    state: present
  become: yes
```

**Problems:**
- No validation that packages exist
- No error handling
- No verification after installation

### ✅ After (With Validation and Verification)
```yaml
# Validate variables first
- name: Validate PostgreSQL installation variables
  assert:
    that:
      - postgresql_major_version is defined
      - postgresql_full_version is defined
      - paths.offline_dir is defined
    fail_msg: "Required PostgreSQL variables not defined"
  tags: [postgres, install, validation, always]

# Find packages before installation
- name: Find PostgreSQL packages in offline directory
  find:
    paths: "{{ paths.offline_dir }}"
    patterns:
      - "postgresql{{ postgresql_major_version }}*.rpm"
      - "libpq5*.rpm"
    file_type: file
  register: postgresql_packages

# Validate packages found
- name: Validate PostgreSQL packages found
  assert:
    that:
      - postgresql_packages.files | length > 0
    fail_msg: "No PostgreSQL packages found"
  tags: [postgres, install, validation]

# Install dependencies (idempotent)
- name: Install PostgreSQL dependencies
  dnf:
    name:
      - perl
      - perl-libs
      - libxslt
      - libxslt-devel
    state: present
  become: yes

# Verify installation
- name: Verify PostgreSQL packages are installed
  command: rpm -q "{{ item.name }}"
  register: postgresql_package_check
  loop: "{{ postgresql_package_list }}"
  changed_when: false
  failed_when: postgresql_package_check.rc != 0
  become: yes
  tags: [postgres, install, validation, verify]
```

**Improvements:**
- ✅ Pre-flight validation
- ✅ Package discovery before installation
- ✅ Post-installation verification
- ✅ Clear error messages
- ✅ Comprehensive tags for selective execution

---

## Variable Structure

### Centralized Versions (`vars/release.yml`)
```yaml
postgresql_major_version: "15"
postgresql_full_version: "15.14"
postgresql_package_version: "15.14-1PGDG.rhel9"
java_full_version: "8u412"
java_legacy_version: "1_8_0_92"
dmc_version: "4.6.33"
```

### Environment Configuration (`vars/env/default.yml`)
```yaml
system_paths:
  java_install_dir: "/usr/j2se"
  offline_dir: "/tmp/offline"

service_ports:
  postgresql: 5432
  dmc_http: 50400
```

### Role Defaults (`roles/<role>/defaults/main.yml`)
```yaml
# Reference centralized versions
postgresql_major_version: "{{ postgresql_major_version | default('15') }}"
java_install_dir: "{{ system_paths.java_install_dir | default('/usr/j2se') }}"
```

---

## Key Refactoring Principles

1. **Idempotence**: Every task must safely re-run
   - Use native modules (`yum`, `dnf`, `file`, `service`)
   - Add `creates:` or `changed_when:` where needed
   - Check state before modifying

2. **Parameterization**: No hardcoded values
   - Versions in `vars/release.yml`
   - Paths in `vars/env/default.yml`
   - Customer overrides in `config/values.yaml`

3. **Validation**: Verify before proceeding
   - Assert variable presence
   - Check prerequisites
   - Validate package existence

4. **Error Handling**: Graceful failures
   - Use `block/rescue` for critical operations
   - Clear error messages
   - Proper failure conditions

5. **Maintainability**: Easy to update
   - Single source of truth for versions
   - Clear variable hierarchy
   - Comprehensive tags

---

## Migration Guide

To upgrade to a new release:

1. **Update `vars/release.yml`**:
   ```yaml
   postgresql_full_version: "15.15"  # Changed from 15.14
   dmc_version: "4.6.34"            # Changed from 4.6.33
   ```

2. **Run playbook** - All roles automatically use new versions

3. **No other files need changes** ✅

This is the power of centralized version management!

