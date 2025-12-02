# Logstash OSS Role for OpenSearch Stack

This Ansible role installs and configures Logstash OSS (Open Source Software) version 8.19.4 specifically for the OpenSearch stack, separate from the regular ELK stack Logstash.

## Features

- Installs Logstash OSS 8.19.4-x86_64.rpm package
- Configures Logstash OSS with OpenSearch-specific settings
- Sets up DMC log processing pipeline
- Installs required plugins (logstash-filter-rest, logstash-output-opensearch)
- Configures custom grok patterns for DMC logs
- Sets up proper service management and logging

## Configuration

### Default Variables

The role uses the following key configuration variables:

- `logstash_oss_version`: "8.19.4"
- `logstash_oss_user`: "logstash"
- `logstash_oss_group`: "logstash"
- `logstash_oss_config.http_host`: "0.0.0.0"
- `logstash_oss_config.pipeline_ecs_compatibility`: "disabled"
- `logstash_oss_config.api_ssl_enabled`: false

### DMC Log Processing

The role processes the following DMC log types:
- EIR logs
- Activity logs
- Add backend logs
- Delivered content logs
- GUI page leave logs
- Profile association logs
- Scenario operation delivered logs
- Mobile binding change logs
- CSV export logs

### OpenSearch Integration

- Outputs data to OpenSearch cluster
- Uses admin credentials for authentication
- Configures proper index patterns (dmc-logs-*, csvexport-*)
- Handles document upserts for CSV export data

## Usage

### Basic Usage

```yaml
- hosts: logstash_oss
  roles:
    - logstash_oss
```

### With Custom Configuration

```yaml
- hosts: logstash_oss
  vars:
    logstash_oss_config:
      opensearch_hosts: ["http://opensearch1:9200", "http://opensearch2:9200"]
      opensearch_user: "admin"
      opensearch_password: "your_password"
      customer_name: "Your Customer Name"
  roles:
    - logstash_oss
```

### Using the OpenSearch Stack Playbook

```bash
ansible-playbook -i inventories/DEV/hosts.ini opensearch-stack.yml
```

## File Structure

```
roles/logstash_oss/
├── defaults/
│   └── main.yml                 # Default variables
├── handlers/
│   └── main.yml                 # Service handlers
├── tasks/
│   ├── main.yml                 # Main task file
│   ├── install_logstash_oss.yml # Installation tasks
│   ├── configure_user.yml       # User configuration
│   ├── configure_directories.yml # Directory setup
│   ├── configure_logstash_oss.yml # Main configuration
│   ├── install_plugins.yml      # Plugin installation
│   ├── configure_service.yml    # Service configuration
│   └── configure_pipeline.yml   # Pipeline configuration
└── templates/
    ├── logstash_oss.yml.j2      # Main configuration template
    ├── jvm.options.j2           # JVM options
    ├── startup.options.j2       # Startup options
    ├── logstash_oss.service.j2  # Systemd service
    ├── logstash_oss_logrotate.j2 # Log rotation
    ├── logstash_oss.conf.j2     # Pipeline configuration
    └── sicap_patterns.j2        # Custom grok patterns
```

## Dependencies

- Ansible 2.9+
- RedHat/CentOS 7+
- Java 11+ (installed by OpenSearch role)
- OpenSearch cluster running

## Tags

- `logstash_oss`: All tasks
- `install`: Installation tasks only
- `user`: User configuration
- `directories`: Directory setup
- `config`: Configuration tasks
- `plugins`: Plugin installation
- `service`: Service configuration
- `pipeline`: Pipeline configuration

## Notes

- This role is specifically designed for the OpenSearch stack
- It uses Logstash OSS 8.19.4 instead of the regular Logstash
- The configuration is optimized for DMC log processing
- ECS compatibility is disabled as per requirements
- SSL is disabled for HTTP calls
- Custom patterns are included for DMC-specific log formats




