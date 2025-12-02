# DMC4.6.18 Installation Makefile
# Ansible-only scaffold with no Python dependencies

# Default environment
ENVIRONMENT ?= TT
INVENTORY ?= ansible/inventories/$(ENVIRONMENT)/hosts.ini
PLAYBOOK ?= ansible/site.yml

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
	@echo "  $(GREEN)prepare$(NC)     - Validate offline packages and system readiness"
	@echo "  $(GREEN)install$(NC)     - Run the complete DMC installation playbook"
	@echo "  $(GREEN)check-inventory$(NC) - Validate inventory file and host connectivity"
	@echo "  $(GREEN)clean$(NC)       - Clean temporary files and logs"
	@echo "  $(GREEN)help$(NC)        - Show this help message"
	@echo ""
	@echo "$(YELLOW)Environment Variables:$(NC)"
	@echo "  $(GREEN)ENVIRONMENT$(NC) - Target environment (TT, DEV) [default: TT]"
	@echo "  $(GREEN)INVENTORY$(NC)   - Custom inventory file path"
	@echo "  $(GREEN)PLAYBOOK$(NC)    - Custom playbook file path"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  $(GREEN)make prepare$(NC)                           # Validate packages for TT environment"
	@echo "  $(GREEN)make install$(NC)                           # Install on TT environment"
	@echo "  $(GREEN)make install ENVIRONMENT=DEV$(NC)           # Install on DEV environment"
	@echo "  $(GREEN)make install INVENTORY=ansible/inventories/DEV/hosts.ini$(NC)"
	@echo "  $(GREEN)make check-inventory$(NC)                   # Test connectivity to all hosts"
	@echo ""
	@echo "$(YELLOW)Current Configuration:$(NC)"
	@echo "  Environment: $(GREEN)$(ENVIRONMENT)$(NC)"
	@echo "  Inventory: $(GREEN)$(INVENTORY)$(NC)"
	@echo "  Playbook: $(GREEN)$(PLAYBOOK)$(NC)"

# Validate offline packages and system readiness
prepare:
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

# Install with specific tags
install-tag:
	@echo "$(BLUE)=== Tagged Installation ===$(NC)"
	@echo "$(YELLOW)Available tags: preflight, postgres, elasticsearch, logstash, kibana$(NC)"
	@echo "$(YELLOW)               dmc1, dmc2, drs, mmg, mmsoap, smppc, sls$(NC)"
	@echo "$(YELLOW)Usage: make install-tag TAG=postgres$(NC)"
	@if [ -z "$(TAG)" ]; then \
		echo "$(RED)ERROR: TAG variable not set$(NC)"; \
		exit 1; \
	fi
	@ansible-playbook -i "$(INVENTORY)" "$(PLAYBOOK)" --tags "$(TAG)" --verbose

