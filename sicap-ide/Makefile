# DMC4.6.18 Installation Makefile
# Ansible-only scaffold with no Python dependencies

# Default environment
ENVIRONMENT ?= TT
INVENTORY ?= ansible/inventories/$(ENVIRONMENT)/hosts.ini
PLAYBOOK ?= ansible/site.yml

# Host pattern for connectivity checks
PATTERN ?= all

# Skip phases (set to 1 to skip)
SKIP_POSTGRES ?= 0
SKIP_POSTGRES_INSTALL ?= false

# Colors for output (disabled - plain text only)
RED := 
GREEN := 
YELLOW := 
BLUE := 
NC := 

.PHONY: help prepare install ping check-inventory clean

# Default target
help:
	@echo "$(BLUE)DMC4.6.18 Installation Makefile$(NC)"
	@echo ""
	@echo "$(YELLOW)Basic Commands:$(NC)"
	@echo "  $(GREEN)make sync-packages$(NC)              - Auto-update versions from offline directory"
	@echo "  $(GREEN)make prepare$(NC)                    - Validate packages and system readiness"
	@echo "  $(GREEN)make install$(NC)                    - Full installation (all components)"
	@echo "  $(GREEN)make install TAG=xxx$(NC)            - Install specific component by tag"
	@echo ""
	@echo "$(YELLOW)Available Tags (make install TAG=xxx):$(NC)"
	@echo "  $(GREEN)postgres, opensearch, logstash-oss, opensearch_dashboards$(NC)"
	@echo "  $(GREEN)dmc1, dmc2, dmc, drs, elkstatistic, sls$(NC)"
	@echo "  $(GREEN)mmg, mmsoap, smppc, zabbix, zabbix-agents, haproxy$(NC)"
	@echo ""
	@echo "$(YELLOW)Module Targets:$(NC)"
	@echo "  $(GREEN)install-elk-stack$(NC)               - Elasticsearch + Logstash + Kibana only"
	@echo "  $(GREEN)install-opensearch-stack$(NC)        - OpenSearch + Logstash-OSS + Dashboards only"
	@echo "  $(GREEN)install-dmc-module-e$(NC)            - DMC module with ELK stack"
	@echo "  $(GREEN)install-dmc-module-o$(NC)            - DMC module with OpenSearch stack"
	@echo "  $(GREEN)install-sls$(NC)                     - SLS (core service)"
	@echo "  $(GREEN)install-mmg-module$(NC)             - MMG module (MMG, MMSOAP, SMPPC)"
	@echo ""
	@echo "$(YELLOW)Utilities:$(NC)"
	@echo "  $(GREEN)ping$(NC)                            - Ping all inventory hosts (clean report)"
	@echo "  $(GREEN)ping PATTERN=dmc1$(NC)               - Ping only one group or host"
	@echo "  $(GREEN)check-inventory$(NC)                 - Validate inventory and connectivity"
	@echo "  $(GREEN)list-packages$(NC)                   - List files in offline directory"
	@echo "  $(GREEN)status$(NC)                          - Show current environment status"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  $(GREEN)make install TAG=elkstatistic$(NC)   - Install only elkstatistic"
	@echo "  $(GREEN)make install TAG=drs$(NC)            - Install only drs"
	@echo "  $(GREEN)make install TAG=sls$(NC)            - Install only SLS"
	@echo "  $(GREEN)make install ENVIRONMENT=DEV$(NC)    - Full install on DEV"
	@echo ""
	@echo "$(YELLOW)Current:$(NC) Environment=$(GREEN)$(ENVIRONMENT)$(NC), Inventory=$(GREEN)$(INVENTORY)$(NC)"

# Quick test: list files in offline directory
list-packages:
	@echo "$(BLUE)=== Quick Test: Listing Offline Packages ===$(NC)"
	@bash scripts/check_offline_artifacts.sh --list-files

# Sync package versions from offline directory to config/values.yaml
sync-packages:
	@echo "$(BLUE)=== Syncing Package Versions ===$(NC)"
	@echo "$(YELLOW)Scanning offline directory and updating config/values.yaml...$(NC)"
	@bash scripts/sync_packages.sh
	@echo "$(GREEN)Γ£ô Package versions synced${NC}"

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
	@echo "$(GREEN)Γ£ô Preflight validation completed successfully$(NC)"
	@echo "$(GREEN)Γ£ô System is ready for installation$(NC)"

# Run the complete DMC installation playbook (removed - merged with tag-based install below)

# Ping every host in the inventory and print a one-line-per-host report
ping:
	@echo "$(BLUE)=== Host Connectivity Check ($(ENVIRONMENT)) ===$(NC)"
	@echo "$(YELLOW)Inventory: $(INVENTORY)  Pattern: $(PATTERN)$(NC)"
	@INVENTORY="$(INVENTORY)" PATTERN="$(PATTERN)" bash scripts/ping_hosts.sh

# Validate inventory file and host connectivity
check-inventory:
	@echo "$(BLUE)=== Inventory Validation ===$(NC)"
	@echo "$(YELLOW)Checking inventory file: $(INVENTORY)$(NC)"
	@if [ ! -f "$(INVENTORY)" ]; then \
		echo "$(RED)ERROR: Inventory file not found: $(INVENTORY)$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Γ£ô Inventory file exists$(NC)"
	@echo ""
	@echo "$(YELLOW)Testing host connectivity...$(NC)"
	@ansible all -i "$(INVENTORY)" -m ping --one-line
	@echo ""
	@echo "$(YELLOW)Inventory groups and hosts:$(NC)"
	@ansible-inventory -i "$(INVENTORY)" --list | grep -E '^\s*"[^"]+"\s*:\s*\{' | sed 's/^[[:space:]]*"\([^"]*\)".*/\1/' | sort
	@echo ""
	@echo "$(GREEN)Γ£ô Inventory validation completed$(NC)"

# Clean temporary files and logs
clean:
	@echo "$(BLUE)=== Cleaning Temporary Files ===$(NC)"
	@echo "$(YELLOW)Removing Ansible temporary files...$(NC)"
	@find . -name "*.retry" -delete 2>/dev/null || true
	@find . -name ".ansible" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "$(YELLOW)Removing log files...$(NC)"
	@find . -name "ansible.log" -delete 2>/dev/null || true
	@find . -name "*.log" -path "./logs/*" -delete 2>/dev/null || true
	@echo "$(GREEN)Γ£ô Cleanup completed$(NC)"

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
	@echo "$(GREEN)Γ£ô Configuration files validated$(NC)"

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
		echo "  Config: $(GREEN)Γ£ô Found$(NC)"; \
	else \
		echo "  Config: $(RED)Γ£ù Missing (copy values.example.yaml)$(NC)"; \
	fi
	@if [ -f "$(INVENTORY)" ]; then \
		echo "  Inventory: $(GREEN)Γ£ô Found$(NC)"; \
	else \
		echo "  Inventory: $(RED)Γ£ù Missing$(NC)"; \
	fi
	@if [ -f "$(PLAYBOOK)" ]; then \
		echo "  Playbook: $(GREEN)Γ£ô Found$(NC)"; \
	else \
		echo "  Playbook: $(RED)Γ£ù Missing$(NC)"; \
	fi
	@if [ -f "scripts/check_offline_artifacts.sh" ]; then \
		echo "  Check Script: $(GREEN)Γ£ô Found$(NC)"; \
	else \
		echo "  Check Script: $(RED)Γ£ù Missing$(NC)"; \
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
	@echo "$(GREEN)Γ£ô DMC installation completed$(NC)"

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
	@echo "$(GREEN)Γ£ô Installation with TAG=$(TAG) completed$(NC)"

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
	@if grep -q 'Create DMC user (normal mode - using Ansible module)' ansible/roles/db_postgres/tasks/dmc_sql_setup.yml; then \
		echo "ERROR: ansible/roles/db_postgres/tasks/dmc_sql_setup.yml is STALE."; \
		echo "That file still has: Create DMC user (normal mode - using Ansible module)"; \
		echo "That task uses login_host None and fails with: could not translate host name None."; \
		echo "Copy ansible/roles/db_postgres/tasks/dmc_sql_setup.yml from Cursor."; \
		echo "It must contain: Create DMC user on inventory postgres host via local psql"; \
		exit 1; \
	fi
	@if ! grep -q 'Create DMC user on inventory postgres host via local psql' ansible/roles/db_postgres/tasks/dmc_sql_setup.yml; then \
		echo "ERROR: ansible/roles/db_postgres/tasks/dmc_sql_setup.yml is missing the local psql DMC user task."; \
		echo "Copy that file from Cursor, then re-run make."; \
		exit 1; \
	fi
	@if grep -q 'Wait for Kibana to be ready after restart' ansible/roles/kibana/tasks/configure_service.yml; then \
		echo "ERROR: ansible/roles/kibana/tasks/configure_service.yml is STALE."; \
		echo "That file still waits 120s on ansible_host:5601 after an unconditional restart."; \
		echo "Copy ansible/roles/kibana/tasks/configure_service.yml from Cursor."; \
		echo "It must contain: Wait for Kibana to listen on localhost"; \
		exit 1; \
	fi
	@if ! grep -q 'Wait for Kibana to listen on localhost' ansible/roles/kibana/tasks/configure_service.yml; then \
		echo "ERROR: ansible/roles/kibana/tasks/configure_service.yml is missing the localhost Kibana wait."; \
		echo "Copy that file from Cursor, then re-run make."; \
		exit 1; \
	fi
	@if grep -q '192\.168\.6\.131' ansible/roles/elasticsearch/files/setup_passwords.sh; then \
		echo "ERROR: ansible/roles/elasticsearch/files/setup_passwords.sh is STALE (hardcoded host 192.168.6.131)."; \
		echo "Copy ansible/roles/elasticsearch/files/setup_passwords.sh from Cursor (no hardcoded host, handles 401)."; \
		exit 1; \
	fi
	@if grep -q '192\.168\.6\.131' sicap-ide/ansible/roles/elasticsearch/files/setup_passwords.sh; then \
		echo "ERROR: sicap-ide/ansible/roles/elasticsearch/files/setup_passwords.sh is STALE (hardcoded host 192.168.6.131)."; \
		echo "Copy the nested setup_passwords.sh from Cursor as well."; \
		exit 1; \
	fi
	@if grep -q 'elasticsearch-setup-passwords interactive -u' ansible/roles/elasticsearch/files/setup_passwords.sh; then \
		echo "ERROR: ansible/roles/elasticsearch/files/setup_passwords.sh is STALE (unexpected -u flag)."; \
		echo "Copy the updated script from Cursor."; \
		exit 1; \
	fi
	@if grep -q 'elasticsearch-setup-passwords interactive -u' sicap-ide/ansible/roles/elasticsearch/files/setup_passwords.sh; then \
		echo "ERROR: sicap-ide/ansible/roles/elasticsearch/files/setup_passwords.sh is STALE (unexpected -u flag)."; \
		echo "Copy the updated nested script from Cursor."; \
		exit 1; \
	fi
	@if ! grep -q 'python3' ansible/roles/elkstatistic/tasks/install_elkstack.yml || ! grep -q 'zipfile' ansible/roles/elkstatistic/tasks/install_elkstack.yml; then \
		echo "ERROR: ansible/roles/elkstatistic/tasks/install_elkstack.yml is STALE."; \
		echo "That file still uses unarchive, which needs unzip (not present on lpdmc1p)."; \
		echo "Copy ansible/roles/elkstatistic/tasks/install_elkstack.yml from Cursor."; \
		echo "It must extract with: python3 -m zipfile"; \
		exit 1; \
	fi
	@if grep -q "line: 'logstash:x:996:993" ansible/roles/logstash/tasks/configure_user.yml; then \
		echo "ERROR: ansible/roles/logstash/tasks/configure_user.yml on THIS host is STALE."; \
		echo "It still has: line: 'logstash:x:996:993:logstash:/opt/logstash:/bin/bash'"; \
		echo "That file was already fixed in Cursor. Sync these two files onto this machine, then re-run:"; \
		echo "  ansible/roles/logstash/tasks/configure_user.yml"; \
		echo "  ansible/tasks/ensure_unique_service_user.yml"; \
		exit 1; \
	fi
	@if ! grep -q 'Ensure logstash user has a unique local UID' ansible/roles/logstash/tasks/configure_user.yml; then \
		echo "ERROR: ansible/roles/logstash/tasks/configure_user.yml is missing the unique-UID include."; \
		echo "Sync ansible/roles/logstash/tasks/configure_user.yml from Cursor."; \
		exit 1; \
	fi
	@if [ ! -f ansible/tasks/ensure_unique_service_user.yml ] || ! grep -q 'sed home and shell' ansible/tasks/ensure_unique_service_user.yml; then \
		echo "ERROR: ansible/tasks/ensure_unique_service_user.yml is missing on THIS host."; \
		echo "Sync ansible/tasks/ensure_unique_service_user.yml from Cursor, then re-run make."; \
		exit 1; \
	fi
ifeq ($(SKIP_POSTGRES),1)
	@echo "$(YELLOW)Note: Skipping PostgreSQL installation play (using external database)$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "preflight,elasticsearch,logstash,kibana,zabbix,zabbix-agents,haproxy,dmc1,dmc2,elkstatistic" --skip-tags "postgres" --extra-vars "stack_type=elk skip_postgres_install=true" --verbose
else ifeq ($(SKIP_POSTGRES_INSTALL),true)
	@echo "$(YELLOW)Note: Skipping PostgreSQL installation tasks (using external database)$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "preflight,postgres,elasticsearch,logstash,kibana,zabbix,zabbix-agents,haproxy,dmc1,dmc2,elkstatistic" --skip-tags "postgres_install" --extra-vars "stack_type=elk skip_postgres_install=true" --verbose
else
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "preflight,postgres,elasticsearch,logstash,kibana,zabbix,zabbix-agents,haproxy,dmc1,dmc2,elkstatistic" --extra-vars "stack_type=elk" --verbose
endif
	@echo ""
	@echo "$(GREEN)Γ£ô DMC + DRS + Logstash installation completed on all DMC machines$(NC)"

install-dmc-module-o:
	@echo "$(BLUE)=== DMC Module Installation (OpenSearch Stack) ===$(NC)"
	@echo "$(YELLOW)Installing DMC + DRS + Logstash-OSS on each DMC machine with OpenSearch stack$(NC)"
	@if grep -q 'Fail when offline pack is present but lacks' ansible/roles/logstash_oss/tasks/install_plugins.yml; then \
		echo "ERROR: ansible/roles/logstash_oss/tasks/install_plugins.yml is STALE."; \
		echo "make is about to run the old task that fails on logstash-offline-plugins-8.19.4.zip."; \
		echo "That zip is the rest pack. OpenSearch install is logstash-output-plugins-openseach-*.zip."; \
		echo "Copy ansible/roles/logstash_oss/tasks/install_plugins.yml from Cursor (must contain: manual file:// flow)."; \
		exit 1; \
	fi
	@if ! grep -q 'manual file:// flow' ansible/roles/logstash_oss/tasks/install_plugins.yml; then \
		echo "ERROR: ansible/roles/logstash_oss/tasks/install_plugins.yml is not the file:// OpenSearch installer."; \
		echo "Copy that file from Cursor, then re-run make."; \
		exit 1; \
	fi
	@if grep -qE '^stack_type:' ansible/roles/logstash_oss/tasks/main.yml; then \
		echo "ERROR: ansible/roles/logstash_oss/tasks/main.yml is defaults/main.yml copied over the task list."; \
		echo "Both files are named main.yml. Restore tasks/main.yml from Cursor (must contain '- name:' includes)."; \
		echo "  roles/logstash_oss/tasks/main.yml     <- task list"; \
		echo "  roles/logstash_oss/defaults/main.yml  <- variables (stack_type:)"; \
		exit 1; \
	fi
	@if ! grep -q 'Include Logstash OSS pipeline configuration tasks' ansible/roles/logstash_oss/tasks/main.yml; then \
		echo "ERROR: ansible/roles/logstash_oss/tasks/main.yml is stale or the wrong file."; \
		echo "Copy roles/logstash_oss/tasks/main.yml from Cursor (pipeline include must run before service)."; \
		exit 1; \
	fi
	@if ! grep -q 'Create logstash conf.d directory' ansible/roles/logstash_oss/tasks/configure_logstash_oss.yml; then \
		echo "ERROR: ansible/roles/logstash_oss/tasks/configure_logstash_oss.yml is stale (no conf.d task)."; \
		echo "Copy that file from Cursor, then re-run make."; \
		exit 1; \
	fi
	@for f in main.yml configure_directories.yml configure_logstash_oss.yml configure_pipeline.yml configure_service.yml install_plugins.yml configure_user.yml install_logstash_oss.yml; do \
		p="ansible/roles/logstash_oss/tasks/$$f"; \
		if ! grep -qE '^- name:' "$$p"; then \
			echo "ERROR: $$p is not an Ansible task list (no line starting with '- name:')."; \
			echo "The wrong file was copied over it (often defaults/main.yml, also named main.yml)."; \
			echo "----- first 15 lines of $$p -----"; \
			head -n 15 "$$p"; \
			echo "Copy roles/logstash_oss/tasks/$$f from Cursor, then re-run make."; \
			exit 1; \
		fi; \
	done
	@if ! grep -q 'Create logstash data directory' ansible/roles/logstash_oss/tasks/configure_directories.yml; then \
		echo "ERROR: ansible/roles/logstash_oss/tasks/configure_directories.yml is the wrong file."; \
		echo "Copy roles/logstash_oss/tasks/configure_directories.yml from Cursor."; \
		exit 1; \
	fi
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
	@echo "$(GREEN)Γ£ô DMC + DRS + Logstash-OSS installation completed on all DMC machines$(NC)"

# Install SLS (core service) and pause for license upload
install-sls:
	@echo "$(BLUE)=== SLS Installation (Core Service) ===$(NC)"
	@echo "$(YELLOW)Installing SLS - the core SICAP service$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "sls" --verbose
	@echo ""
	@echo "$(GREEN)Γ£ô SLS installation completed$(NC)"
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
	@echo "$(GREEN)Γ£ô MMG module installation completed$(NC)"

# Stack Selection Targets
install-elk-stack:
	@echo "$(BLUE)=== ELK Stack Installation ===$(NC)"
	@echo "$(YELLOW)Installing Elasticsearch, Logstash, Kibana$(NC)"
	@if grep -q "line: 'logstash:x:996:993" ansible/roles/logstash/tasks/configure_user.yml; then \
		echo "ERROR: ansible/roles/logstash/tasks/configure_user.yml on THIS host is STALE."; \
		echo "It still has: line: 'logstash:x:996:993:logstash:/opt/logstash:/bin/bash'"; \
		echo "That file was already fixed in Cursor. Sync these two files onto this machine, then re-run:"; \
		echo "  ansible/roles/logstash/tasks/configure_user.yml"; \
		echo "  ansible/tasks/ensure_unique_service_user.yml"; \
		exit 1; \
	fi
	@if ! grep -q 'Ensure logstash user has a unique local UID' ansible/roles/logstash/tasks/configure_user.yml; then \
		echo "ERROR: ansible/roles/logstash/tasks/configure_user.yml is missing the unique-UID include."; \
		echo "Sync ansible/roles/logstash/tasks/configure_user.yml from Cursor."; \
		exit 1; \
	fi
	@if [ ! -f ansible/tasks/ensure_unique_service_user.yml ] || ! grep -q 'sed home and shell' ansible/tasks/ensure_unique_service_user.yml; then \
		echo "ERROR: ansible/tasks/ensure_unique_service_user.yml is missing on THIS host."; \
		echo "Sync ansible/tasks/ensure_unique_service_user.yml from Cursor, then re-run make."; \
		exit 1; \
	fi
	@if grep -q 'same filter logic as before' ansible/roles/logstash/templates/logstash.conf.j2; then \
		echo "ERROR: ansible/roles/logstash/templates/logstash.conf.j2 is STALE (stub pipeline)."; \
		echo "Sync ansible/roles/logstash/templates/logstash.conf.j2 from Cursor."; \
		exit 1; \
	fi
	@if ! grep -q 'tcp {' ansible/roles/logstash/templates/logstash.conf.j2 || ! grep -q ':9292/drs' ansible/roles/logstash/templates/logstash.conf.j2; then \
		echo "ERROR: logstash.conf.j2 is missing tcp input or DRS port 9292."; \
		echo "Sync ansible/roles/logstash/templates/logstash.conf.j2 from Cursor."; \
		exit 1; \
	fi
	@if grep -q 'notify: restart logstash' ansible/roles/logstash/tasks/configure_logstash.yml; then \
		echo "ERROR: ansible/roles/logstash/tasks/configure_logstash.yml still notifies 'restart logstash'."; \
		echo "include_tasks cannot see role handlers, so the play fails. Sync that file from Cursor."; \
		exit 1; \
	fi
	@if ! grep -q 'files still owned by sssd' ansible/tasks/ensure_unique_service_user.yml; then \
		echo "ERROR: ansible/tasks/ensure_unique_service_user.yml is missing sssd leftover reclaim."; \
		echo "After UID remap, /var/opt/logstash/data/queue stays owned by sssd. Sync that file from Cursor."; \
		exit 1; \
	fi
	@if [ ! -f ansible/tasks/ensure_logstash_ilm_policies.yml ] || ! grep -q 'dmc-logs_history' ansible/tasks/ensure_logstash_ilm_policies.yml; then \
		echo "ERROR: ansible/tasks/ensure_logstash_ilm_policies.yml is missing."; \
		echo "Logstash requires ILM policies dmc-logs_history and csvexport_history. Sync that file from Cursor."; \
		exit 1; \
	fi
	@if ! grep -q 'ilm_enabled => false' ansible/roles/logstash/templates/logstash.conf.j2; then \
		echo "ERROR: logstash.conf.j2 still lets Logstash manage ILM (custom ilm_policy)."; \
		echo "That reports 'policy does not exist' even when Elasticsearch has the policy. Sync the template from Cursor."; \
		exit 1; \
	fi
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "elasticsearch,logstash,kibana" --extra-vars "stack_type=elk" --verbose
	@echo ""
	@echo "$(GREEN)ELK stack installation completed$(NC)"

install-opensearch-stack:
	@echo "$(BLUE)=== OpenSearch Stack Installation ===$(NC)"
	@echo "$(YELLOW)Installing OpenSearch, Logstash-OSS, OpenSearch-Dashboards$(NC)"
	@if grep -q "opensearch:x:983:983" ansible/roles/opensearch/tasks/configure_user.yml; then \
		echo "ERROR: ansible/roles/opensearch/tasks/configure_user.yml is STALE (hardcoded UID 983:983)."; \
		echo "Copy configure_user.yml from Cursor."; \
		exit 1; \
	fi
	@if grep -q "logstash:x:982:982" ansible/roles/logstash_oss/tasks/configure_user.yml; then \
		echo "ERROR: ansible/roles/logstash_oss/tasks/configure_user.yml is STALE (hardcoded UID 982:982)."; \
		echo "Copy configure_user.yml from Cursor."; \
		exit 1; \
	fi
	@if ! grep -q 'sed home and shell' ansible/tasks/ensure_unique_service_user.yml; then \
		echo "ERROR: ansible/tasks/ensure_unique_service_user.yml is missing the sed home/shell task."; \
		echo "Copy that file from Cursor, then re-run make."; \
		exit 1; \
	fi
	@if ! grep -q 'files still owned by sssd' ansible/tasks/ensure_unique_service_user.yml; then \
		echo "ERROR: ansible/tasks/ensure_unique_service_user.yml is missing sssd leftover reclaim."; \
		echo "After UID remap, data/log children stay owned by sssd. Sync that file from Cursor."; \
		exit 1; \
	fi
	@if grep -q 'Fail when offline pack is present but lacks' ansible/roles/logstash_oss/tasks/install_plugins.yml; then \
		echo "ERROR: ansible/roles/logstash_oss/tasks/install_plugins.yml is STALE."; \
		echo "Copy that file from Cursor (must contain: manual file:// flow)."; \
		exit 1; \
	fi
	@if grep -q 'notify: restart logstash-oss' ansible/roles/logstash_oss/tasks/configure_pipeline.yml; then \
		echo "ERROR: ansible/roles/logstash_oss/tasks/configure_pipeline.yml still notifies 'restart logstash-oss'."; \
		echo "include_tasks cannot see role handlers, so the play fails. Sync that file from Cursor."; \
		exit 1; \
	fi
	@if ! grep -q 'Remove leftover x-pack directory' ansible/roles/logstash_oss/tasks/install_logstash_oss.yml; then \
		echo "ERROR: ansible/roles/logstash_oss/tasks/install_logstash_oss.yml is missing the x-pack cleanup."; \
		echo "A leftover /usr/share/logstash/x-pack makes logstash-oss fail with:"; \
		echo "  (LoadError) no such file to load -- x-pack/logstash_registry"; \
		echo "Sync that file from Cursor, then re-run make."; \
		exit 1; \
	fi
	@if ! grep -q 'Environment=OSS=true' ansible/roles/logstash_oss/tasks/configure_logstash_oss.yml; then \
		echo "ERROR: ansible/roles/logstash_oss/tasks/configure_logstash_oss.yml is missing Environment=OSS=true."; \
		echo "Without it logstash-core loads x-pack whenever that directory exists."; \
		echo "Sync that file from Cursor, then re-run make."; \
		exit 1; \
	fi
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "opensearch,logstash-oss,logstash_oss,opensearch_dashboards" --extra-vars "stack_type=opensearch" --verbose
	@echo ""
	@echo "$(GREEN)OpenSearch stack installation completed$(NC)"

# Complete installation workflows
install-complete-elk: install-dmc-module-e install-sls install-mmg-module
	@echo "$(BLUE)=== Complete ELK Installation Workflow ===$(NC)"
	@echo "$(GREEN)Γ£ô All components installed with ELK stack$(NC)"

install-complete-opensearch: install-dmc-module-o install-sls install-mmg-module
	@echo "$(BLUE)=== Complete OpenSearch Installation Workflow ===$(NC)"
	@echo "$(GREEN)Γ£ô All components installed with OpenSearch stack$(NC)"

# Install Logstash OSS only
install-logstash-oss:
	@echo "$(BLUE)=== Install Logstash OSS ===$(NC)"
	@echo "$(YELLOW)Installing Logstash OSS 8.19.4 independently$(NC)"
	@ansible-playbook -i "$(INVENTORY)" ansible/install-logstash-oss.yml --tags "logstash-oss" --verbose
	@echo ""
	@echo "$(GREEN)Γ£ô Logstash OSS installation completed$(NC)"


# Update Provider ID (run after provider creation via web interface)
providerid:
	@echo "$(BLUE)=== Update Provider ID ===$(NC)"
	@echo "$(YELLOW)Updating provider ID in DMC configuration files$(NC)"
	@echo "$(YELLOW)This should be run AFTER creating a provider via DMC web interface$(NC)"
	@ansible-playbook -i "$(INVENTORY)" ansible/update_provider_id.yml --verbose
	@echo ""
	@echo "$(GREEN)Γ£ô Provider ID updated successfully$(NC)"
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
	@echo "$(GREEN)Γ£ô Installation resumed from Zabbix with ELK stack$(NC)"
	@echo "$(YELLOW)Next: Run 'make install-sls' then 'make install-mmg-module'$(NC)"

resume-from-zabbix-o:
	@echo "$(BLUE)=== Resume Installation from Zabbix (OpenSearch Stack) ===$(NC)"
	@echo "$(YELLOW)Resuming installation starting from Zabbix with OpenSearch stack$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "zabbix,zabbix-agents,dmc1,dmc2" --extra-vars "stack_type=opensearch" --verbose
	@echo ""
	@echo "$(GREEN)Γ£ô Installation resumed from Zabbix with OpenSearch stack$(NC)"
	@echo "$(YELLOW)Next: Run 'make install-sls' then 'make install-mmg-module'$(NC)"

# Resume from DMC module (DMC + DRS + Logstash only)
resume-from-dmc-e:
	@echo "$(BLUE)=== Resume DMC Module Installation (ELK Stack) ===$(NC)"
	@echo "$(YELLOW)Resuming DMC module installation with ELK stack$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "dmc1,dmc2" --extra-vars "stack_type=elk" --verbose
	@echo ""
	@echo "$(GREEN)Γ£ô DMC module installation resumed with ELK stack$(NC)"
	@echo "$(YELLOW)Next: Run 'make install-sls' then 'make install-mmg-module'$(NC)"

resume-from-dmc-o:
	@echo "$(BLUE)=== Resume DMC Module Installation (OpenSearch Stack) ===$(NC)"
	@echo "$(YELLOW)Resuming DMC module installation with OpenSearch stack$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "dmc1,dmc2" --extra-vars "stack_type=opensearch" --verbose
	@echo ""
	@echo "$(GREEN)Γ£ô DMC module installation resumed with OpenSearch stack$(NC)"
	@echo "$(YELLOW)Next: Run 'make install-sls' then 'make install-mmg-module'$(NC)"

# Resume from SLS (core service)
resume-from-sls:
	@echo "$(BLUE)=== Resume Installation from SLS ===$(NC)"
	@echo "$(YELLOW)Resuming installation starting from SLS (core service)$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "sls" --verbose
	@echo ""
	@echo "$(GREEN)Γ£ô SLS installation resumed$(NC)"
	@echo "$(YELLOW)Next: Run 'make install-mmg-module'$(NC)"

# Resume from MMG module (MMG + MMSOAP + SMPPC)
resume-from-mmg:
	@echo "$(BLUE)=== Resume Installation from MMG Module ===$(NC)"
	@echo "$(YELLOW)Resuming installation starting from MMG module$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "mmg,mmsoap,smppc" --verbose
	@echo ""
	@echo "$(GREEN)Γ£ô MMG module installation resumed and completed$(NC)"

# Resume from HAProxy
resume-from-haproxy:
	@echo "$(BLUE)=== Resume Installation from HAProxy ===$(NC)"
	@echo "$(YELLOW)Resuming installation starting from HAProxy$(NC)"
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "haproxy" --verbose
	@echo ""
	@echo "$(GREEN)Γ£ô HAProxy installation resumed and completed$(NC)"

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
