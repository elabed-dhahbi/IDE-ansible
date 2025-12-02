# DMC4.6.18 Installation Makefile
# Ansible-only scaffold with no Python dependencies

# Default environment
ENVIRONMENT ?= TT
INVENTORY ?= ansible/inventories/$(ENVIRONMENT)/hosts.ini
PLAYBOOK ?= ansible/site.yml

# Skip phases (set to 1 to skip)
SKIP_POSTGRES ?= 0
SKIP_POSTGRES_INSTALL ?= false

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: help prepare install check-inventory clean

# Default target
help:
	@echo "$(BLUE)DMC4.6.18 Installation Makefile$(NC)"
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@echo "  $(GREEN)sync-packages$(NC) - Scan offline directory and update versions in config/values.yaml"
	@echo "  $(GREEN)prepare$(NC)     - Sync packages, then validate offline packages and system readiness"
	@echo "  $(GREEN)install$(NC)     - Run the complete DMC installation playbook (all components)"
	@echo "  $(GREEN)install TAG=xxx$(NC) - Install specific component(s) by tag (e.g., TAG=elkstatistic, TAG=drs)"
	@echo ""
	@echo "  $(GREEN)Main Installation Targets:$(NC)"
	@echo "  $(GREEN)install-dmc-only$(NC) - Install DMC only (without DRS, Logstash, etc.)"
	@echo "  $(GREEN)install-dmc-module -e$(NC) - Install DMC module with DRS, Logstash and ELK stack"
	@echo "  $(GREEN)install-dmc-module -o$(NC) - Install DMC module with DRS, Logstash and OpenSearch stack"
	@echo "  $(GREEN)install-sls$(NC) - Install SLS (core service) and pause for license upload"
	@echo "  $(GREEN)install-mmg-module$(NC) - Install MMG module (MMG, MMSOAP, SMPPC)"
	@echo ""
	@echo "  $(GREEN)Stack-Only Targets:$(NC)"
	@echo "  $(GREEN)install-elk-stack$(NC) - Install ELK stack only (Elasticsearch, Logstash, Kibana)"
	@echo "  $(GREEN)install-opensearch-stack$(NC) - Install OpenSearch stack only (OpenSearch, Logstash-OSS, Dashboards)"
	@echo ""
	@echo "  $(GREEN)Complete Workflows:$(NC)"
	@echo "  $(GREEN)install-complete-elk$(NC) - Complete installation with ELK stack"
	@echo "  $(GREEN)install-complete-opensearch$(NC) - Complete installation with OpenSearch stack"
	@echo ""
	@echo "  $(GREEN)install-logstash-oss$(NC) - Install Logstash OSS independently"
	@echo "  $(GREEN)install-zabbix$(NC) - Install Zabbix monitoring server"
	@echo "  $(GREEN)install-zabbix-agents$(NC) - Install Zabbix agents on all hosts"
	@echo "  $(GREEN)providerid$(NC)  - Update provider ID in DMC config files (run after provider creation)"
	@echo ""
	@echo "  $(GREEN)Resume Installation Targets:$(NC)"
	@echo "  $(GREEN)resume-from-zabbix-e$(NC) - Resume from Zabbix with ELK stack"
	@echo "  $(GREEN)resume-from-zabbix-o$(NC) - Resume from Zabbix with OpenSearch stack"
	@echo "  $(GREEN)resume-from-dmc-e$(NC) - Resume DMC module with ELK stack"
	@echo "  $(GREEN)resume-from-dmc-o$(NC) - Resume DMC module with OpenSearch stack"
	@echo "  $(GREEN)resume-from-sls$(NC) - Resume from SLS (core service)"
	@echo "  $(GREEN)resume-from-mmg$(NC) - Resume from MMG module"
	@echo "  $(GREEN)resume-from-haproxy$(NC) - Resume from HAProxy"
	@echo "  $(GREEN)resume-smart$(NC) - Smart resume (auto-detect stack type)"
	@echo ""
	@echo "  $(GREEN)check-inventory$(NC) - Validate inventory file and host connectivity"
	@echo "  $(GREEN)list-packages$(NC) - Quick test: list all files in offline directory"
	@echo "  $(GREEN)clean$(NC)       - Clean temporary files and logs"
	@echo "  $(GREEN)help$(NC)        - Show this help message"
	@echo ""
	@echo "$(YELLOW)Environment Variables:$(NC)"
	@echo "  $(GREEN)ENVIRONMENT$(NC) - Target environment (TT, DEV) [default: TT]"
	@echo "  $(GREEN)INVENTORY$(NC)   - Custom inventory file path"
	@echo "  $(GREEN)PLAYBOOK$(NC)    - Custom playbook file path"
	@echo "  $(GREEN)SKIP_POSTGRES$(NC) - Skip PostgreSQL installation play [default: 0, set to 1 to skip]"
	@echo "  $(GREEN)SKIP_POSTGRES_INSTALL$(NC) - Skip PostgreSQL installation tasks only [default: false, set to true to skip]"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  $(GREEN)make sync-packages$(NC)                     # Update versions from offline directory"
	@echo "  $(GREEN)make prepare$(NC)                           # Sync packages, then validate for TT environment"
	@echo "  $(GREEN)make install$(NC)                           # Full installation (all components)"
	@echo "  $(GREEN)make install TAG=elkstatistic$(NC)          # Install only elkstatistic component"
	@echo "  $(GREEN)make install TAG=drs$(NC)                    # Install only drs component"
	@echo "  $(GREEN)make install TAG=sls$(NC)                   # Install only SLS component"
	@echo "  $(GREEN)make install TAG=postgres$(NC)              # Install only PostgreSQL"
	@echo "  $(GREEN)make install TAG=opensearch$(NC)            # Install only OpenSearch"
	@echo "  $(GREEN)make install TAG=zabbix$(NC)                # Install only Zabbix"
	@echo "  $(GREEN)make install TAG=haproxy$(NC)               # Install only HAProxy"
	@echo "  $(GREEN)make install ENVIRONMENT=DEV$(NC)           # Full install on DEV environment"
	@echo "  $(GREEN)make install TAG=drs ENVIRONMENT=DEV$(NC)    # Install drs on DEV environment"
	@echo "  $(GREEN)make check-inventory$(NC)                   # Test connectivity to all hosts"
	@echo "  $(GREEN)make install-sls$(NC)                       # Install SLS standalone (for license upload)"
	@echo "  $(GREEN)make install-dmc-module-e SKIP_POSTGRES=1$(NC)  # Install DMC with ELK, skip PostgreSQL play"
	@echo "  $(GREEN)make install-dmc-module-o SKIP_POSTGRES=1$(NC)  # Install DMC with OpenSearch, skip PostgreSQL play"
	@echo ""
	@echo "$(YELLOW)Resume Examples:$(NC)"
	@echo "  $(GREEN)make resume-from-dmc-e$(NC)                 # Resume DMC with ELK stack"
	@echo "  $(GREEN)make resume-from-dmc-o$(NC)                 # Resume DMC with OpenSearch stack"
	@echo "  $(GREEN)make resume-smart STACK=e$(NC)              # Smart resume with ELK stack"
	@echo "  $(GREEN)make resume-from-sls$(NC)                   # Resume from SLS if DMC completed"
	@echo "  $(GREEN)make resume-from-mmg$(NC)                   # Resume from MMG if SLS completed"
	@echo ""
	@echo "$(YELLOW)Current Configuration:$(NC)"
	@echo "  Environment: $(GREEN)$(ENVIRONMENT)$(NC)"
	@echo "  Inventory: $(GREEN)$(INVENTORY)$(NC)"
	@echo "  Playbook: $(GREEN)$(PLAYBOOK)$(NC)"

# Quick test: list files in offline directory
list-packages:
	@echo "$(BLUE)=== Quick Test: Listing Offline Packages ===$(NC)"
	@bash scripts/check_offline_artifacts.sh --list-files

# Sync package versions from offline directory to config/values.yaml
sync-packages:
	@echo "$(BLUE)=== Syncing Package Versions ===$(NC)"
	@echo "$(YELLOW)Scanning offline directory and updating config/values.yaml...$(NC)"
	@bash scripts/sync_packages.sh
	@echo "$(GREEN)✓ Package versions synced${NC}"

# Validate offline packages and system readiness
prepare: sync-packages
	@echo "$(BLUE)=== DMC4.6.18 Installation Preparation ===$(NC)"
	@echo "$(YELLOW)Validating offline packages...$(NC)"
	@if [ ! -f "$(INVENTORY)" ]; then \
		echo "$(RED)ERROR: Inventory file not found: $(INVENTORY)$(NC)"; \
		echo "$(YELLOW)Available environments:$(NC)"; \
		ls -1 ansible/inventories/ 2>/dev/null || echo "$(RED)No inventory directories found$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f "config/values.yaml" ]; then \
		echo "$(RED)ERROR: Configuration file not found: config/values.yaml$(NC)"; \
		echo "$(YELLOW)Please copy config/values.example.yaml to config/values.yaml and customize it.$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Running offline artifacts validation...$(NC)"
	@INVENTORY_FILE="$(INVENTORY)" bash scripts/check_offline_artifacts.sh
	@echo "$(GREEN)✓ Preflight validation completed successfully$(NC)"
	@echo "$(GREEN)✓ System is ready for installation$(NC)"

# Run the complete DMC installation playbook
install: prepare
	@echo "$(BLUE)=== DMC4.6.18 Installation ===$(NC)"
	@echo "$(YELLOW)Starting installation on $(ENVIRONMENT) environment...$(NC)"
	@echo "$(YELLOW)Inventory: $(INVENTORY)$(NC)"
	@echo "$(YELLOW)Playbook: $(PLAYBOOK)$(NC)"
	@echo ""
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" \
		--extra-vars "environment=$(ENVIRONMENT)" \
		--verbose
	@echo ""
	@echo "$(GREEN)✓ Installation completed successfully$(NC)"
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Verify all services are running"
	@echo "  2. Check service logs for any issues"
	@echo "  3. Configure application-specific settings"
	@echo "  4. Test service connectivity"

# Validate inventory file and host connectivity
check-inventory:
	@echo "$(BLUE)=== Inventory Validation ===$(NC)"
	@echo "$(YELLOW)Checking inventory file: $(INVENTORY)$(NC)"
	@if [ ! -f "$(INVENTORY)" ]; then \
		echo "$(RED)ERROR: Inventory file not found: $(INVENTORY)$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ Inventory file exists$(NC)"
	@echo ""
	@echo "$(YELLOW)Testing host connectivity...$(NC)"
	@ansible all -i "$(INVENTORY)" -m ping --one-line
	@echo ""
	@echo "$(YELLOW)Inventory groups and hosts:$(NC)"
	@ansible-inventory -i "$(INVENTORY)" --list | grep -E '^\s*"[^"]+"\s*:\s*\{' | sed 's/^[[:space:]]*"\([^"]*\)".*/\1/' | sort
	@echo ""
	@echo "$(GREEN)✓ Inventory validation completed$(NC)"

# Clean temporary files and logs
clean:
	@echo "$(BLUE)=== Cleaning Temporary Files ===$(NC)"
	@echo "$(YELLOW)Removing Ansible temporary files...$(NC)"
	@find . -name "*.retry" -delete 2>/dev/null || true
	@find . -name ".ansible" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "$(YELLOW)Removing log files...$(NC)"
	@find . -name "ansible.log" -delete 2>/dev/null || true
	@find . -name "*.log" -path "./logs/*" -delete 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup completed$(NC)"

# Validate configuration files
validate-config:
	@echo "$(BLUE)=== Configuration Validation ===$(NC)"
	@echo "$(YELLOW)Checking configuration files...$(NC)"
	@if [ ! -f "config/values.yaml" ]; then \
		echo "$(RED)ERROR: config/values.yaml not found$(NC)"; \
		echo "$(YELLOW)Please copy config/values.example.yaml to config/values.yaml$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f "$(INVENTORY)" ]; then \
		echo "$(RED)ERROR: Inventory file not found: $(INVENTORY)$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ Configuration files validated$(NC)"

# Show current environment status
status:
	@echo "$(BLUE)=== DMC4.6.18 Environment Status ===$(NC)"
	@echo "$(YELLOW)Current Configuration:$(NC)"
	@echo "  Environment: $(GREEN)$(ENVIRONMENT)$(NC)"
	@echo "  Inventory: $(GREEN)$(INVENTORY)$(NC)"
	@echo "  Playbook: $(GREEN)$(PLAYBOOK)$(NC)"
	@echo ""
	@echo "$(YELLOW)File Status:$(NC)"
	@if [ -f "config/values.yaml" ]; then \
		echo "  Config: $(GREEN)✓ Found$(NC)"; \
	else \
		echo "  Config: $(RED)✗ Missing (copy values.example.yaml)$(NC)"; \
	fi
	@if [ -f "$(INVENTORY)" ]; then \
		echo "  Inventory: $(GREEN)✓ Found$(NC)"; \
	else \
		echo "  Inventory: $(RED)✗ Missing$(NC)"; \
	fi
	@if [ -f "$(PLAYBOOK)" ]; then \
		echo "  Playbook: $(GREEN)✓ Found$(NC)"; \
	else \
		echo "  Playbook: $(RED)✗ Missing$(NC)"; \
	fi
	@if [ -f "scripts/check_offline_artifacts.sh" ]; then \
		echo "  Check Script: $(GREEN)✓ Found$(NC)"; \
	else \
		echo "  Check Script: $(RED)✗ Missing$(NC)"; \
	fi

# Install with specific tags (legacy target - use 'make install TAG=xxx' instead)
# Kept for backward compatibility
install-tag:
	@echo "$(BLUE)=== Tagged Installation (Legacy) ===$(NC)"
	@echo "$(YELLOW)Note: Use 'make install TAG=xxx' instead of 'make install-tag TAG=xxx'$(NC)"
	@echo "$(YELLOW)Available tags: preflight, postgres, elasticsearch, logstash, kibana$(NC)"
	@echo "$(YELLOW)               opensearch, logstash-oss, opensearch_dashboards$(NC)"
	@echo "$(YELLOW)               dmc1, dmc2, drs, mmg, mmsoap, smppc, sls$(NC)"
	@echo "$(YELLOW)               zabbix, zabbix-agents, elkstatistic, haproxy$(NC)"
	@echo "$(YELLOW)Usage: make install-tag TAG=postgres$(NC)"
	@if [ -z "$(TAG)" ]; then \
		echo "$(RED)ERROR: TAG variable not set$(NC)"; \
		exit 1; \
	fi
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "$(TAG)" --extra-vars "stack_type=opensearch" --verbose

# Install Zabbix monitoring server
install-zabbix:
	@echo "$(BLUE)=== Zabbix Server Installation ===$(NC)"
	@echo "$(YELLOW)Installing Zabbix monitoring server$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "zabbix" --extra-vars "stack_type=elk" --verbose

# Install Zabbix agents on all hosts
install-zabbix-agents:
	@echo "$(BLUE)=== Zabbix Agents Installation ===$(NC)"
	@echo "$(YELLOW)Installing Zabbix agents on all hosts except Zabbix server$(NC)"
	@ansible-playbook -i "$(INVENTORY)" install-zabbix-agents.yml --verbose

# Install DMC only (without DRS, Logstash, etc.)
# Usage: make install-dmc-only [SKIP_POSTGRES=1] [SKIP_POSTGRES_INSTALL=true]
install-dmc-only:
	@echo "$(BLUE)=== DMC Only Installation ===$(NC)"
	@echo "$(YELLOW)Installing DMC only (without DRS, Logstash, and other modules)$(NC)"
ifeq ($(SKIP_POSTGRES),1)
	@echo "$(YELLOW)Note: Skipping PostgreSQL installation play (using external database)$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "preflight,dmc1,dmc2,dmc" --skip-tags "postgres,drs,logstash,logstash-oss" --extra-vars "stack_type=opensearch skip_postgres_install=true" --verbose
else ifeq ($(SKIP_POSTGRES_INSTALL),true)
	@echo "$(YELLOW)Note: Skipping PostgreSQL installation tasks (using external database)$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "preflight,postgres,dmc1,dmc2,dmc" --skip-tags "postgres_install,drs,logstash,logstash-oss" --extra-vars "stack_type=opensearch skip_postgres_install=true" --verbose
else
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "preflight,postgres,dmc1,dmc2,dmc" --skip-tags "drs,logstash,logstash-oss" --extra-vars "stack_type=opensearch" --verbose
endif
	@echo ""
	@echo "$(GREEN)✓ DMC installation completed$(NC)"

# Install using TAG variable (for individual roles)
# Usage: make install TAG=drs or make install TAG=logstash-oss or make install TAG=dmc
# This installs only the specified role, no common role, no PostgreSQL
install:
ifndef TAG
	@echo "$(RED)ERROR: TAG variable is required$(NC)"
	@echo "$(YELLOW)Usage: make install TAG=drs$(NC)"
	@echo "$(YELLOW)Example: make install TAG=logstash-oss$(NC)"
	@exit 1
endif
	@echo "$(BLUE)=== Installation with TAG=$(TAG) ===$(NC)"
ifeq ($(TAG),dmc)
	$(eval TAGS := dmc1,dmc2,dmc)
	@echo "$(YELLOW)Installing DMC only (skipping PostgreSQL installation, using external database)$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "$(TAGS)" --skip-tags "postgres,postgres_install,drs,logstash,logstash-oss" --extra-vars "stack_type=opensearch skip_postgres_install=true" --verbose
else
	$(eval TAGS := $(TAG))
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "$(TAGS)" --extra-vars "stack_type=opensearch" --verbose
endif
	@echo ""
	@echo "$(GREEN)✓ Installation with TAG=$(TAG) completed$(NC)"

# Install DMC module (complete DMC installation)
install-dmc-module:
	@echo "$(BLUE)=== DMC Module Installation ===$(NC)"
	@echo "$(YELLOW)Installing complete DMC module with dependencies$(NC)"
	@echo "$(YELLOW)Usage: make install-dmc-module -e (ELK) or -o (OpenSearch)$(NC)"
	@echo "$(RED)ERROR: Please specify stack type with -e (ELK) or -o (OpenSearch)$(NC)"
	@exit 1

install-dmc-module-e:
	@echo "$(BLUE)=== DMC Module Installation (ELK Stack) ===$(NC)"
	@echo "$(YELLOW)Installing DMC + DRS + Logstash on each DMC machine with ELK stack$(NC)"
ifeq ($(SKIP_POSTGRES),1)
	@echo "$(YELLOW)Note: Skipping PostgreSQL installation play (using external database)$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "preflight,elasticsearch,kibana,zabbix,zabbix-agents,haproxy,dmc1,dmc2,elkstatistic" --skip-tags "postgres" --extra-vars "stack_type=elk skip_postgres_install=true" --verbose
else ifeq ($(SKIP_POSTGRES_INSTALL),true)
	@echo "$(YELLOW)Note: Skipping PostgreSQL installation tasks (using external database)$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "preflight,postgres,elasticsearch,kibana,zabbix,zabbix-agents,haproxy,dmc1,dmc2,elkstatistic" --skip-tags "postgres_install" --extra-vars "stack_type=elk skip_postgres_install=true" --verbose
else
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "preflight,postgres,elasticsearch,kibana,zabbix,zabbix-agents,haproxy,dmc1,dmc2,elkstatistic" --extra-vars "stack_type=elk" --verbose
endif
	@echo ""
	@echo "$(GREEN)✓ DMC + DRS + Logstash installation completed on all DMC machines$(NC)"

install-dmc-module-o:
	@echo "$(BLUE)=== DMC Module Installation (OpenSearch Stack) ===$(NC)"
	@echo "$(YELLOW)Installing DMC + DRS + Logstash-OSS on each DMC machine with OpenSearch stack$(NC)"
ifeq ($(SKIP_POSTGRES),1)
	@echo "$(YELLOW)Note: Skipping PostgreSQL installation play (using external database)$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "preflight,opensearch,logstash-oss,opensearch_dashboards,zabbix,zabbix-agents,haproxy,dmc1,dmc2,elkstatistic" --skip-tags "postgres" --extra-vars "stack_type=opensearch skip_postgres_install=true" --verbose
else ifeq ($(SKIP_POSTGRES_INSTALL),true)
	@echo "$(YELLOW)Note: Skipping PostgreSQL installation tasks (using external database)$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "preflight,postgres,opensearch,logstash-oss,opensearch_dashboards,zabbix,zabbix-agents,haproxy,dmc1,dmc2,elkstatistic" --skip-tags "postgres_install" --extra-vars "stack_type=opensearch skip_postgres_install=true" --verbose
else
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "preflight,postgres,opensearch,logstash-oss,opensearch_dashboards,zabbix,zabbix-agents,haproxy,dmc1,dmc2,elkstatistic" --extra-vars "stack_type=opensearch" --verbose
endif
	@echo ""
	@echo "$(GREEN)✓ DMC + DRS + Logstash-OSS installation completed on all DMC machines$(NC)"

# Install SLS (core service) and pause for license upload
install-sls:
	@echo "$(BLUE)=== SLS Installation (Core Service) ===$(NC)"
	@echo "$(YELLOW)Installing SLS - the core SICAP service$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "sls" --verbose
	@echo ""
	@echo "$(GREEN)✓ SLS installation completed$(NC)"
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Upload ALL licenses via browser (SLS, MMG, MMSOAP, SMPPC, etc.)"
	@echo "  2. Verify SLS is working"
	@echo "  3. Run: make install-mmg-module"

# Install MMG module (MMG, MMSOAP, SMPPC)
install-mmg-module:
	@echo "$(BLUE)=== MMG Module Installation ===$(NC)"
	@echo "$(YELLOW)Installing MMG, MMSOAP, SMPPC (requires SLS to be licensed)$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "mmg,mmsoap,smppc" --verbose
	@echo ""
	@echo "$(GREEN)✓ MMG module installation completed$(NC)"

# Stack Selection Targets
install-elk-stack:
	@echo "$(BLUE)=== ELK Stack Installation ===$(NC)"
	@echo "$(YELLOW)Installing Elasticsearch, Logstash, Kibana$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "elasticsearch,logstash,kibana" --extra-vars "stack_type=elk" --verbose
	@echo ""
	@echo "$(GREEN)✓ ELK stack installation completed$(NC)"

install-opensearch-stack:
	@echo "$(BLUE)=== OpenSearch Stack Installation ===$(NC)"
	@echo "$(YELLOW)Installing OpenSearch, Logstash-OSS, OpenSearch-Dashboards$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "opensearch,logstash-oss,opensearch_dashboards" --extra-vars "stack_type=opensearch" --verbose
	@echo ""
	@echo "$(GREEN)✓ OpenSearch stack installation completed$(NC)"

# Complete installation workflows
install-complete-elk: install-dmc-module-e install-sls install-mmg-module
	@echo "$(BLUE)=== Complete ELK Installation Workflow ===$(NC)"
	@echo "$(GREEN)✓ All components installed with ELK stack$(NC)"

install-complete-opensearch: install-dmc-module-o install-sls install-mmg-module
	@echo "$(BLUE)=== Complete OpenSearch Installation Workflow ===$(NC)"
	@echo "$(GREEN)✓ All components installed with OpenSearch stack$(NC)"

# Install Logstash OSS only
install-logstash-oss:
	@echo "$(BLUE)=== Install Logstash OSS ===$(NC)"
	@echo "$(YELLOW)Installing Logstash OSS 8.19.4 independently$(NC)"
	@ansible-playbook -i "$(INVENTORY)" ansible/install-logstash-oss.yml --tags "logstash-oss" --verbose
	@echo ""
	@echo "$(GREEN)✓ Logstash OSS installation completed$(NC)"


# Update Provider ID (run after provider creation via web interface)
providerid:
	@echo "$(BLUE)=== Update Provider ID ===$(NC)"
	@echo "$(YELLOW)Updating provider ID in DMC configuration files$(NC)"
	@echo "$(YELLOW)This should be run AFTER creating a provider via DMC web interface$(NC)"
	@ansible-playbook -i "$(INVENTORY)" ansible/update_provider_id.yml --verbose
	@echo ""
	@echo "$(GREEN)✓ Provider ID updated successfully$(NC)"
	@echo "$(YELLOW)DMC service has been restarted with the new provider ID$(NC)"

# Resume Installation Targets
# These targets allow you to resume installation from any specific point
# Note: SLS is separate from DMC module and comes after DMC installation

# Resume from Zabbix (includes all subsequent services)
resume-from-zabbix-e:
	@echo "$(BLUE)=== Resume Installation from Zabbix (ELK Stack) ===$(NC)"
	@echo "$(YELLOW)Resuming installation starting from Zabbix with ELK stack$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "zabbix,zabbix-agents,dmc1,dmc2" --extra-vars "stack_type=elk" --verbose
	@echo ""
	@echo "$(GREEN)✓ Installation resumed from Zabbix with ELK stack$(NC)"
	@echo "$(YELLOW)Next: Run 'make install-sls' then 'make install-mmg-module'$(NC)"

resume-from-zabbix-o:
	@echo "$(BLUE)=== Resume Installation from Zabbix (OpenSearch Stack) ===$(NC)"
	@echo "$(YELLOW)Resuming installation starting from Zabbix with OpenSearch stack$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "zabbix,zabbix-agents,dmc1,dmc2" --extra-vars "stack_type=opensearch" --verbose
	@echo ""
	@echo "$(GREEN)✓ Installation resumed from Zabbix with OpenSearch stack$(NC)"
	@echo "$(YELLOW)Next: Run 'make install-sls' then 'make install-mmg-module'$(NC)"

# Resume from DMC module (DMC + DRS + Logstash only)
resume-from-dmc-e:
	@echo "$(BLUE)=== Resume DMC Module Installation (ELK Stack) ===$(NC)"
	@echo "$(YELLOW)Resuming DMC module installation with ELK stack$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "dmc1,dmc2" --extra-vars "stack_type=elk" --verbose
	@echo ""
	@echo "$(GREEN)✓ DMC module installation resumed with ELK stack$(NC)"
	@echo "$(YELLOW)Next: Run 'make install-sls' then 'make install-mmg-module'$(NC)"

resume-from-dmc-o:
	@echo "$(BLUE)=== Resume DMC Module Installation (OpenSearch Stack) ===$(NC)"
	@echo "$(YELLOW)Resuming DMC module installation with OpenSearch stack$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "dmc1,dmc2" --extra-vars "stack_type=opensearch" --verbose
	@echo ""
	@echo "$(GREEN)✓ DMC module installation resumed with OpenSearch stack$(NC)"
	@echo "$(YELLOW)Next: Run 'make install-sls' then 'make install-mmg-module'$(NC)"

# Resume from SLS (core service)
resume-from-sls:
	@echo "$(BLUE)=== Resume Installation from SLS ===$(NC)"
	@echo "$(YELLOW)Resuming installation starting from SLS (core service)$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "sls" --verbose
	@echo ""
	@echo "$(GREEN)✓ SLS installation resumed$(NC)"
	@echo "$(YELLOW)Next: Run 'make install-mmg-module'$(NC)"

# Resume from MMG module (MMG + MMSOAP + SMPPC)
resume-from-mmg:
	@echo "$(BLUE)=== Resume Installation from MMG Module ===$(NC)"
	@echo "$(YELLOW)Resuming installation starting from MMG module$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "mmg,mmsoap,smppc" --verbose
	@echo ""
	@echo "$(GREEN)✓ MMG module installation resumed and completed$(NC)"

# Resume from HAProxy
resume-from-haproxy:
	@echo "$(BLUE)=== Resume Installation from HAProxy ===$(NC)"
	@echo "$(YELLOW)Resuming installation starting from HAProxy$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "haproxy" --verbose
	@echo ""
	@echo "$(GREEN)✓ HAProxy installation resumed and completed$(NC)"

# Smart resume - tries to detect what was already installed
resume-smart:
	@echo "$(BLUE)=== Smart Resume Installation ===$(NC)"
	@echo "$(YELLOW)Attempting to detect installation state and resume appropriately$(NC)"
	@echo "$(YELLOW)Please specify the stack type: make resume-smart STACK=e (ELK) or STACK=o (OpenSearch)$(NC)"
	@if [ -z "$(STACK)" ]; then \
		echo "$(RED)ERROR: STACK variable not set$(NC)"; \
		echo "$(YELLOW)Usage: make resume-smart STACK=e (for ELK) or STACK=o (for OpenSearch)$(NC)"; \
		exit 1; \
	fi
	@if [ "$(STACK)" = "e" ]; then \
		echo "$(YELLOW)Resuming with ELK stack...$(NC)"; \
		$(MAKE) resume-from-dmc-e; \
	elif [ "$(STACK)" = "o" ]; then \
		echo "$(YELLOW)Resuming with OpenSearch stack...$(NC)"; \
		$(MAKE) resume-from-dmc-o; \
	else \
		echo "$(RED)ERROR: Invalid STACK value. Use 'e' for ELK or 'o' for OpenSearch$(NC)"; \
		exit 1; \
	fi

