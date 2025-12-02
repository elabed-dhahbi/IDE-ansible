# DMC4.6.18 Configuration Guide

This document explains how to configure the DMC4.6.18 Ansible installation scaffold for your environment.

## Overview

The DMC4.6.18 installation uses a simple, Ansible-only approach with:
- **Static inventories** for host management
- **YAML configuration** for versions and settings
- **Glob patterns** for offline package discovery
- **Bash scripts** for validation (no Python dependencies)

## Configuration Components

### 1. Host IPs and Hostnames

Host IPs and hostnames are configured directly in static inventory files:

```
ansible/inventories/<ENVIRONMENT>/hosts.ini
```

**Example:**
```ini
[dmc1]
lpdmc1 ansible_host=192.168.1.10

[mmsoap]
lpmmsoap1 ansible_host=192.168.1.20   # REQUIRED

[sls]
lpsls1 ansible_host=192.168.1.30      # REQUIRED
```

**Available Environments:**
- `DEV` - Development environment
- `TT` - Test environment

**Required Groups:**
- `mmsoap` - MMSOAP service (REQUIRED)
- `sls` - SLS service (REQUIRED)
- `dmc2` - Optional second DMC node

### 2. Component Versions

All component versions are managed in the central configuration file:

```
config/values.yaml
```

**Key Version Settings:**
```yaml
versions:
  dmc: "4.6.18"
  mmg: "4.6.21"
  mmsoap: "5.6.1"
  smppc: "5.4.9"
  sls: "2.0.3"
  postgres: "15"
  elasticsearch: "7.10.2"
  kibana: "7.10.2"
  logstash: "7.17.5"
  jdk8: "8u362"
```

### 3. iOS Enabler Configuration

The iOS enabler configuration is managed through the `ios_enabler` section in `values.yaml`:

**Configuration:**
```yaml
ios_enabler:
  public_ip: "{{ iosPublicIP }}"  # Public IP for iOS enabler external access
  local_ip: "{{ ansible_host }}"  # Local IP from hosts.ini
  mmg_host: "{{ hostvars[groups['mmg'][0]]['ansible_host'] if groups['mmg'] is defined and groups['mmg'] | length > 0 else 'localhost' }}"
  mmg_port: 50434
  mmg_username: "dmc"
  mmg_password: "ZG1j"  # Base64 encoded 'dmc'
  node_id_dmc1: "iosenabler01"
  node_id_dmc2: "iosenabler02"
  connector_port: 50452
  scep_port: 50455
  challenge_port: 50400
```

**Key Features:**
- **Enable/Disable Switch**: Set `ios_enabler.enabled: true/false` to control iOS enabler configuration
- **Dynamic Node ID**: Automatically selects `iosenabler01` for DMC1 and `iosenabler02` for DMC2
- **MMG Integration**: Configures device notification WebService URLs
- **Session Timeouts**: Extended to 72 hours (259200 seconds) for production use
- **Enrollment Configuration**: Optimized retry and timeout settings
- **iOS Version Support**: Extended regexp patterns to support iOS 4-17

### 4. Offline Package Discovery

Offline packages are discovered using glob patterns under `/tmp/offline`:

**Configuration:**
```yaml
paths:
  offline_dir: /tmp/offline
  
  # PostgreSQL directories (production-ready configuration)
  postgres_data_dir: /data/pgsql      # PostgreSQL data directory
  postgres_home_dir: /home/postgres   # PostgreSQL user home directory
  postgres_tablespaces_dir: /data/postgres  # Directory for PostgreSQL tablespaces

package_globs:
  dmc_rpm: "SCPdmc-{{ versions.dmc }}*.rpm"
  mmg_rpm: "SCPmmg-{{ versions.mmg }}*.rpm"
  mmsoap_rpm: "SCPmmsoap-{{ versions.mmsoap }}*.rpm"
  # ... more patterns
```

**Package Resolution:**
- Patterns are resolved using shell globbing
- Packages are validated before installation
- Missing packages cause installation to fail

## Setup Instructions

### Step 1: Copy Configuration Template

```bash
cp config/values.example.yaml config/values.yaml
```

### Step 2: Customize Configuration

Edit `config/values.yaml` with your specific:
- Component versions
- Package glob patterns
- System flags (SELinux, firewall, etc.)
- Hugepages settings

### Step 3: Configure Inventory

Edit the appropriate inventory file:
```bash
# For DEV environment
vim ansible/inventories/DEV/hosts.ini

# For TT environment  
vim ansible/inventories/TT/hosts.ini
```

Uncomment and set the correct IP addresses for your hosts.

### Step 4: Configure PostgreSQL Directories

For production environments, configure custom PostgreSQL directories:

```yaml
paths:
  postgres_data_dir: /data/pgsql      # Custom data directory
  postgres_home_dir: /home/postgres   # Custom home directory  
  postgres_tablespaces_dir: /data/postgres  # Tablespaces directory
```

This implements the production-ready directory structure from your installation notes, separating data and home directories for better performance and data protection.

### Step 5: Prepare Offline Packages

Place all required RPM packages in `/tmp/offline` (or your configured directory):

**Required Packages:**
- PostgreSQL repository: `pgdg-redhat-repo-latest.noarch.rpm`
- Elasticsearch: `elasticsearch-7.10.2*.rpm`
- Kibana: `kibana-7.10.2*.rpm`
- Logstash: `logstash-7.17.5*.rpm`
- JDK8: `openlogic-openjdk-jre-8u*linux*.tar.gz`

**Conditional Packages (based on inventory groups):**
- DMC: `SCPdmc-4.6.18*.rpm`
- MMG: `SCPmmg-4.6.21*.rpm`
- MMSOAP: `SCPmmsoap-5.6.1*.rpm` (REQUIRED)
- SMPPC: `SCPsmppc-5.4.9*.rpm`
- SLS: `SCPsls-2.0.3*.rpm` (REQUIRED)

### Step 6: Validate Configuration

Run the preflight validation:

```bash
make prepare
```

This will:
- Validate all configuration files
- Check offline package availability
- Verify inventory connectivity
- Ensure system readiness

### Step 7: Install DMC

Run the complete installation:

```bash
# For TT environment (default)
make install

# For DEV environment
make install ENVIRONMENT=DEV

# With custom inventory
make install INVENTORY=ansible/inventories/CUSTOM/hosts.ini
```

## PostgreSQL Directory Management

The PostgreSQL role implements production-ready directory configuration:

**Features:**
- **Custom Data Directory**: Moves from `/var/lib/pgsql` to `/data/pgsql` (configurable)
- **Custom Home Directory**: Changes postgres user home from `/var/lib/pgsql` to `/home/postgres`
- **Tablespaces**: Creates dedicated directories for database tablespaces
- **Migration Support**: Automatically migrates existing data using `rsync`
- **Service Configuration**: Updates systemd service file and PostgreSQL configuration

**Directory Structure:**
```
/data/pgsql/15/data/          # PostgreSQL data directory
/home/postgres/               # PostgreSQL user home
/data/postgres/db1/tablespaces/  # Tablespaces directory
├── dmc4tab/                  # DMC data tablespace
├── dmc4idx/                  # DMC index tablespace
├── mmgtab/                   # MMG data tablespace
├── mmgidx/                   # MMG index tablespace
├── mdbatab/                  # MDBA data tablespace
└── mdbaidx/                  # MDBA index tablespace
```

## Package Validation

The `scripts/check_offline_artifacts.sh` script validates package availability:

**Features:**
- Reads configuration from `config/values.yaml`
- Resolves glob patterns using shell globbing
- Checks conditional packages based on inventory groups
- Provides detailed validation report
- Exits with error code if packages missing

**Usage:**
```bash
# Validate with default TT inventory
./scripts/check_offline_artifacts.sh

# Validate with specific inventory
./scripts/check_offline_artifacts.sh -i ansible/inventories/DEV/hosts.ini

# Show help
./scripts/check_offline_artifacts.sh --help
```

## Makefile Targets

**Available Commands:**

- `make help` - Show help and usage information
- `make prepare` - Validate packages and system readiness
- `make install` - Run complete DMC installation
- `make check-inventory` - Validate inventory and test connectivity
- `make clean` - Clean temporary files and logs
- `make status` - Show current environment status

**Environment Variables:**
- `ENVIRONMENT` - Target environment (TT, DEV)
- `INVENTORY` - Custom inventory file path
- `PLAYBOOK` - Custom playbook file path

## Service Configuration

After installation, services are configured with:

**Service IPs:** Available via `service_ips.*` variables in Ansible
**Ports:** Standard ports (DMC: 50400, MMSOAP: 50434, SLS: 50420, etc.)
**Users:** Service-specific users (dmc, mmsoap, sls, etc.)
**Directories:** Standard installation paths (/opt/dmc, /opt/mmsoap, etc.)

### iOS Enabler Configuration File

The DMC installation automatically creates and configures the `dmiosenabler-configuration.properties` file with the following parameters:

**File Location:** `/opt/dmc/current/standalone/configuration/dmiosenabler-configuration.properties`

**Key Parameters:**
- `device.notification.mmg.ws.url` - MMG WebService URL for device notifications
- `device.notification.mmg.ws.username` - MMG WebService username (dmc)
- `device.notification.mmg.ws.password` - MMG WebService password (Base64 encoded)
- `device.notification.mmg.ws.nodeId` - Node ID (iosenabler01 for DMC1, iosenabler02 for DMC2)
- `enabler.frontend.host` - Local DMC IP address
- `enabler.api.provider.host` - Local DMC IP address
- `connector.http.base.server.url` - Public IP with port 50452 for external access
- `session.server.timeout` - Extended to 72 hours (259200 seconds)
- `enrollment.retries` - Reduced to 1 for production
- `enrollment.config.timeout` - Extended to 72 hours (259200 seconds)
- `enrollment.scep.payloadcontent.url` - Public IP with port 50455 for SCEP
- `enrollment.scep.challenge.url` - Local IP with port 50400 for challenge
- `ios4.header.regexp` - Extended pattern supporting iOS 4-15

**Configuration Variables:**
The file is automatically generated using variables from `values.yaml` and the inventory, ensuring consistent configuration across all DMC nodes.

**Enable/Disable iOS Enabler:**
To enable or disable iOS enabler configuration, set the `enabled` flag in `values.yaml`:

```yaml
ios_enabler:
  enabled: true   # Set to true to enable iOS enabler configuration
  public_ip: "203.0.113.1"  # Your public IP address
  # ... other configuration
```

- **`enabled: true`** - iOS enabler configuration will be applied
- **`enabled: false`** - iOS enabler configuration will be skipped (default)

## Troubleshooting

### Common Issues

1. **Missing Packages:**
   - Run `make prepare` to identify missing packages
   - Ensure packages are in correct directory
   - Check package naming matches glob patterns

2. **Inventory Errors:**
   - Run `make check-inventory` to test connectivity
   - Verify host IP addresses are correct
   - Check SSH access to all hosts

3. **Configuration Errors:**
   - Ensure `config/values.yaml` exists and is valid YAML
   - Check version numbers match available packages
   - Verify all required groups are defined in inventory

### Validation Commands

```bash
# Check configuration files
make validate-config

# Test host connectivity
make check-inventory

# Validate packages
make prepare

# Show environment status
make status
```

## Next Steps

After successful installation:

1. **Verify Services:** Check all services are running
2. **Review Logs:** Check service logs for any issues
3. **Configure Applications:** Set up application-specific configurations
4. **Test Connectivity:** Verify inter-service communication
5. **Apply Licenses:** Install and configure license files

For detailed application configuration, refer to the individual component documentation and your internal installation notes.
