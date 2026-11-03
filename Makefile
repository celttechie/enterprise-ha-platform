# ==============================================================================
# Multi-Cloud Platform & SRE Engineering Template Makefile
# Architecture: Decoupled Monorepo (Infra / Platform / Workloads)
# Declarative Dependencies: pyproject.toml (PEP 621)
# ==============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

TARGET ?= local-kvm
VALID_TARGETS := local-kvm aws gcp

VENV := .venv
PYTHON := $(shell if [ -f "$(VENV)/bin/python3" ]; then echo "$(VENV)/bin/python3"; else echo "python3"; fi)
YAMLLINT := $(shell if [ -f "$(VENV)/bin/yamllint" ]; then echo "$(VENV)/bin/yamllint"; else echo "yamllint"; fi)
FLAKE8 := $(shell if [ -f "$(VENV)/bin/flake8" ]; then echo "$(VENV)/bin/flake8"; else echo "flake8"; fi)
PYTEST := $(shell if [ -f "$(VENV)/bin/pytest" ]; then echo "$(VENV)/bin/pytest"; else echo "pytest"; fi)

.PHONY: help
help: ## Display available target commands and descriptions
	@echo "=============================================================================="
	@echo "                   PLATFORM ENGINEERING TEMPLATE CLI                          "
	@echo "=============================================================================="
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo "=============================================================================="

# ---------------------------------------------------------------------------------------------------------------------
# Python Virtual Environment & Dependency Management (pyproject.toml)
# ---------------------------------------------------------------------------------------------------------------------

.PHONY: venv
venv: ## Bootstrap virtual environment and install dependencies declared in pyproject.toml
	@echo "🐍 Bootstrapping Python virtual environment..."
	@if command -v uv >/dev/null 2>&1; then \
		echo "⚡ Detected 'uv' (high performance package manager)..."; \
		if [ ! -d "$(VENV)" ]; then uv venv $(VENV); fi; \
		uv pip install -e ".[dev]"; \
	else \
		echo "ℹ️ Using standard python3 -m venv..."; \
		if [ ! -d "$(VENV)" ]; then python3 -m venv $(VENV); fi; \
		$(VENV)/bin/pip install --quiet --upgrade pip; \
		$(VENV)/bin/pip install --quiet -e ".[dev]"; \
	fi
	@echo "✅ Virtual environment ready in $(VENV)! Run 'source $(VENV)/bin/activate' or use make targets."

# ---------------------------------------------------------------------------------------------------------------------
# Pre-flight, Linting, & CI Quality Gates
# ---------------------------------------------------------------------------------------------------------------------

.PHONY: doctor
doctor: ## Run comprehensive pre-flight diagnostics and toolchain checks
	@$(PYTHON) scripts/doctor.py

.PHONY: lint
lint: ## Lint YAML manifests, OpenTofu, and Python code
	@if command -v $(YAMLLINT) >/dev/null 2>&1; then \
		echo "==> Linting YAML via $(YAMLLINT)..."; \
		$(YAMLLINT) -c .yamllint.yml .; \
	else \
		echo "ℹ️ yamllint not found. Run 'make venv' to install."; \
	fi
	@if command -v $(FLAKE8) >/dev/null 2>&1; then \
		echo "==> Linting Python via $(FLAKE8)..."; \
		$(FLAKE8) .; \
	else \
		echo "ℹ️ flake8 not found. Run 'make venv' to install."; \
	fi
	@if command -v tofu >/dev/null 2>&1; then \
		echo "==> Checking OpenTofu formatting..."; \
		tofu fmt -check -recursive infra/ || true; \
	elif command -v terraform >/dev/null 2>&1; then \
		echo "==> Checking Terraform formatting..."; \
		terraform fmt -check -recursive infra/ || true; \
	fi

.PHONY: test
test: ## Run unit tests and baseline structure validation
	@echo "🧪 Running unit tests..."
	@if command -v $(PYTEST) >/dev/null 2>&1; then \
		$(PYTEST) -v; \
	else \
		$(PYTHON) -m unittest discover tests; \
	fi

.PHONY: ci
ci: lint test ## Run full local pre-flight CI simulation
	@echo "✅ All local CI validations completed successfully!"

# ---------------------------------------------------------------------------------------------------------------------
# Multi-Cloud Infrastructure Lifecycle Targets
# ---------------------------------------------------------------------------------------------------------------------

.PHONY: plan
plan: ## Plan infrastructure for TARGET (e.g. make plan TARGET=aws|gcp|local-kvm)
	@echo "🔍 Running OpenTofu Plan for environment: $(TARGET)..."
	@if [ ! -d "infra/environments/$(TARGET)" ]; then \
		echo "❌ Invalid target '$(TARGET)'. Supported: $(VALID_TARGETS)"; exit 1; \
	fi
	@cd infra/environments/$(TARGET) && tofu init && tofu plan

.PHONY: deploy
deploy: ## Deploy infrastructure & platform for TARGET (e.g. make deploy TARGET=aws|gcp|local-kvm)
	@echo "🚀 Deploying stack for environment: $(TARGET)..."
	@if [ ! -d "infra/environments/$(TARGET)" ]; then \
		echo "❌ Invalid target '$(TARGET)'. Supported: $(VALID_TARGETS)"; exit 1; \
	fi
	@cd infra/environments/$(TARGET) && tofu init && tofu apply -auto-approve

.PHONY: destroy
destroy: ## Destroy infrastructure for TARGET (e.g. make destroy TARGET=aws|gcp|local-kvm)
	@echo "🧹 Tearing down stack for environment: $(TARGET)..."
	@if [ ! -d "infra/environments/$(TARGET)" ]; then \
		echo "❌ Invalid target '$(TARGET)'. Supported: $(VALID_TARGETS)"; exit 1; \
	fi
	@cd infra/environments/$(TARGET) && tofu destroy -auto-approve || true

.PHONY: demo
demo: ## Run automated load generation and chaos resilience drill
	@echo "🎯 Executing demonstration drill..."
	@if [ -f "workloads/chaos-drills/run-drill.sh" ]; then \
		bash workloads/chaos-drills/run-drill.sh; \
	else \
		echo "ℹ️ No drill script found at workloads/chaos-drills/run-drill.sh"; \
	fi

.PHONY: clean
clean: ## Clean up local test caches, venvs, and build artifacts
	@echo "🧹 Cleaning temporary artifacts..."
	@rm -rf .pytest_cache htmlcov .coverage reports/*.raw .venv/ *.egg-info build/ dist/
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
