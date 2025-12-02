# Stack Selection Guide

This project supports both ELK and OpenSearch stacks with simple command-line options.

## Quick Start

### ELK Stack Installation
```bash
# Install DMC module with ELK stack dependencies
make install-dmc-module -e

# Complete ELK installation workflow
make install-complete-elk
```

### OpenSearch Stack Installation
```bash
# Install DMC module with OpenSearch stack dependencies
make install-dmc-module -o

# Complete OpenSearch installation workflow
make install-complete-opensearch
```

## Available Commands

### Main Installation Targets
- `make install-dmc-module -e` - Install DMC module with ELK stack dependencies
- `make install-dmc-module -o` - Install DMC module with OpenSearch stack dependencies
- `make install-sls` - Install SLS (core service) and pause for license upload
- `make install-mmg-module` - Install MMG module (MMG, MMSOAP, SMPPC)

### Stack-Only Targets
- `make install-elk-stack` - Install ELK stack only (Elasticsearch, Logstash, Kibana)
- `make install-opensearch-stack` - Install OpenSearch stack only (OpenSearch, Logstash-OSS, Dashboards)

### Complete Workflows
- `make install-complete-elk` - Complete installation with ELK stack
- `make install-complete-opensearch` - Complete installation with OpenSearch stack

## How It Works

1. **Command-line Options**: The `-e` and `-o` options are passed as `--extra-vars "stack_type=elk"` or `--extra-vars "stack_type=opensearch"` to Ansible
2. **Template Selection**: Logstash configuration templates automatically adapt based on the `stack_type` variable
3. **Role Selection**: Different roles are executed based on the stack type (elasticsearch vs opensearch)
4. **Dependency Management**: DMC module automatically installs the required stack as a dependency

## Stack Differences

### ELK Stack
- Elasticsearch 7.17.25 with security enabled
- Kibana with custom base path
- Standard Logstash with Elasticsearch output
- Password: `elastic`

### OpenSearch Stack
- OpenSearch 2.19.2 with security disabled for DMC compatibility
- OpenSearch Dashboards with multi-tenancy
- Logstash-OSS with OpenSearch output
- Password: `Ops@#s1cap#`
- GPG signature verification
- Custom user profiles and environment setup

## Examples

```bash
# Install everything with ELK stack
make install-complete-elk

# Install everything with OpenSearch stack
make install-complete-opensearch

# Install just the DMC module with ELK dependencies
make install-dmc-module -e

# Install just the DMC module with OpenSearch dependencies
make install-dmc-module -o

# Install just the stacks (without DMC)
make install-elk-stack
make install-opensearch-stack
```










