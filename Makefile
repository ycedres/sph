# Makefile for Salt package updates
# Usage: make update [DRY_RUN=1] [GIT_PUSH=1]

SHELL := /bin/bash
.SHELLFLAGS := -e -u -o pipefail -c

# =============================================================================
# Configuration - Your Development Environment
# =============================================================================

# Source repository (GitHub with embedded packaging)
GITHUB_SOURCE_GIT ?= https://github.com/ycedres/salt-1
GITHUB_BRANCH ?= embed-packaging

# Target package-git repository (Gitea)
GITEA_PACKAGE_GIT ?= ygutierrez/salt
GITEA_SERVER ?= src.opensuse.org

# OBS projects for submission
OBS_PROJECT ?= home:ygutierrez:branches:systemsmanagement:saltstack
OBS_DEV_PROJECT ?= home:ygutierrez:branches:home:ygutierrez:branches:systemsmanagement:saltstack/salt
OBS_API ?= https://api.opensuse.org

# Gitea token for git-obs (Leap branches)
GITEA_TOKEN ?=

# Target branch in package-git (factory, leap-16.1, sle-15.7, etc.)
BRANCH ?= factory

# =============================================================================
# Control flags
# =============================================================================

# Set to 1 to see what would happen without actually doing it
DRY_RUN ?= 0

# Set to 1 to push changes to Gitea
GIT_PUSH ?= 0

# Set to 1 to submit to OBS
OBS_SUBMIT ?= 0

# =============================================================================
# Working directories
# =============================================================================

WORK_DIR := $(shell pwd)
TMP_DIR := $(shell mktemp -d -t salt-build-XXXXXX)
SOURCE_DIR := $(TMP_DIR)/salt-source
PACKAGE_DIR := $(WORK_DIR)

# Files to copy from pkg/suse/ in source repo
PKG_FILES := README.SUSE _multibuild salt.spec update-documentation.sh \
             transactional_update.conf salt-tmpfiles.d html.tar.bz2

# =============================================================================
# Targets
# =============================================================================

.PHONY: help
help:
	@echo "Salt Package Update Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make update              # Dry-run mode (safe)"
	@echo "  make update GIT_PUSH=1   # Update and push to Gitea"
	@echo "  make update OBS_SUBMIT=1 # Update and submit to OBS"
	@echo ""
	@echo "Main targets:"
	@echo "  update        - Full update workflow"
	@echo "  fetch         - Fetch source from GitHub"
	@echo "  extract       - Extract packaging files"
	@echo "  commit        - Commit changes"
	@echo "  push          - Push to Gitea"
	@echo "  submit        - Submit to OBS"
	@echo "  status        - Show current status"
	@echo "  clean         - Clean temporary files"
	@echo ""
	@echo "Configuration:"
	@echo "  GITHUB_SOURCE_GIT = $(GITHUB_SOURCE_GIT)"
	@echo "  GITHUB_BRANCH     = $(GITHUB_BRANCH)"
	@echo "  GITEA_PACKAGE_GIT = $(GITEA_PACKAGE_GIT)"
	@echo "  BRANCH            = $(BRANCH)"
	@echo "  OBS_PROJECT       = $(OBS_PROJECT)"
	@echo "  OBS_DEV_PROJECT   = $(OBS_DEV_PROJECT)"
	@echo ""
	@echo "Submission method:"
	@if echo "$(BRANCH)" | grep -qi "leap"; then \
		echo "  Leap branch → git-obs PR from $(OBS_DEV_PROJECT) to $(OBS_PROJECT)"; \
	else \
		echo "  Factory branch → OBS SR from $(OBS_DEV_PROJECT) to $(OBS_PROJECT)"; \
	fi
	@echo ""
	@echo "Flags:"
	@echo "  DRY_RUN    = $(DRY_RUN)  (1=show what would happen, 0=execute)"
	@echo "  GIT_PUSH   = $(GIT_PUSH)  (1=push to Gitea, 0=local only)"
	@echo "  OBS_SUBMIT = $(OBS_SUBMIT)  (1=submit to OBS, 0=skip)"

# Main workflow
.PHONY: update
update: validate fetch extract commit push
	@echo ""
	@echo "Update complete!"
	@echo ""
	@echo "Next steps:"
	@if [ "$(GIT_PUSH)" = "0" ]; then \
		echo "  - Review changes with: git diff HEAD~1"; \
		echo "  - Push with: make push GIT_PUSH=1"; \
	fi
	@if [ "$(OBS_SUBMIT)" = "0" ]; then \
		echo "  - Submit to OBS with: make submit OBS_SUBMIT=1"; \
	fi

# Validate prerequisites
.PHONY: validate
validate:
	@echo ""
	@echo "Validating prerequisites..."
	@command -v git >/dev/null 2>&1 || (echo "ERROR: git not found" && exit 1)
	@command -v rsync >/dev/null 2>&1 || (echo "ERROR: rsync not found" && exit 1)
	@if [ "$(OBS_SUBMIT)" = "1" ]; then \
		command -v osc >/dev/null 2>&1 || (echo "ERROR: osc not found (required for OBS)" && exit 1); \
	fi
	@test -d .git || (echo "ERROR: Not in a git repository" && exit 1)
	@echo "  All prerequisites met"

# Fetch source from GitHub
.PHONY: fetch
fetch:
	@echo ""
	@echo "Fetching source from GitHub..."
	@echo "  Repository: $(GITHUB_SOURCE_GIT)"
	@echo "  Branch: $(GITHUB_BRANCH)"
	@echo "  Target: $(SOURCE_DIR)"
	@git clone --quiet --depth 1 --branch $(GITHUB_BRANCH) $(GITHUB_SOURCE_GIT) $(SOURCE_DIR)
	@COMMIT_HASH=$$(cd $(SOURCE_DIR) && git rev-parse --short HEAD) && \
		echo "  Fetched commit: $$COMMIT_HASH"

# Extract packaging files from source
.PHONY: extract
extract:
	@echo ""
	@echo "Extracting packaging files..."
	@echo "  Removing old salt/ directory..."
	@rm -rf salt
	@echo "  Copying salt source (without .git)..."
	@cp -r $(SOURCE_DIR) salt
	@rm -rf salt/.git*
	@echo "  Extracting pkg/suse/ files to root..."
	@for file in $(PKG_FILES); do \
		if [ -f "salt/pkg/suse/$$file" ]; then \
			cp "salt/pkg/suse/$$file" . && echo "    [OK] $$file"; \
		else \
			echo "    [WARNING] salt/pkg/suse/$$file not found"; \
		fi; \
	done
	@echo "  Extracting changelog for branch: $(BRANCH)"
	@if [ -f "salt/pkg/suse/changelogs/$(BRANCH).changes" ]; then \
		cp "salt/pkg/suse/changelogs/$(BRANCH).changes" salt.changes && \
		echo "    [OK] salt.changes (from $(BRANCH).changes)"; \
	else \
		echo "    [WARNING] salt/pkg/suse/changelogs/$(BRANCH).changes not found"; \
	fi
	@echo "  Extraction complete"

# Commit changes
.PHONY: commit
commit:
	@echo ""
	@echo "Committing changes..."
	@git add -A
	@if git diff --cached --quiet; then \
		echo "  [INFO] No changes to commit"; \
	else \
		COMMIT_HASH=$$(cd $(SOURCE_DIR) && git rev-parse --short HEAD) && \
		COMMIT_MSG="Update to ycedres/salt-1@$$COMMIT_HASH" && \
		if [ "$(DRY_RUN)" = "1" ]; then \
			echo "  [DRY RUN] Would commit with message: $$COMMIT_MSG"; \
			git diff --cached --stat; \
		else \
			git commit -m "$$COMMIT_MSG" && \
			echo "  [OK] Committed: $$COMMIT_MSG"; \
		fi; \
	fi

# Push to Gitea
.PHONY: push
push:
	@echo ""
	@echo "Pushing to Gitea..."
	@if [ "$(GIT_PUSH)" != "1" ]; then \
		echo "  [SKIP] Skipped (GIT_PUSH=0)"; \
		echo "    Set GIT_PUSH=1 to push"; \
	elif git rev-list --count @{u}..HEAD 2>/dev/null | grep -q "^0$$"; then \
		echo "  [INFO] No commits to push"; \
	else \
		if [ "$(DRY_RUN)" = "1" ]; then \
			echo "  [DRY RUN] Would push to origin/$(BRANCH)"; \
			git log --oneline @{u}..HEAD; \
		else \
			git push origin $(BRANCH) && \
			echo "  [OK] Pushed to origin/$(BRANCH)"; \
		fi; \
	fi

# Submit to OBS or create PR (delegated to branch-specific makefiles)
.PHONY: submit
submit:
	@echo ""
	@if [ "$(OBS_SUBMIT)" != "1" ]; then \
		echo "  [SKIP] Skipped (OBS_SUBMIT=0)"; \
		echo "    Set OBS_SUBMIT=1 to submit"; \
	else \
		if echo "$(BRANCH)" | grep -qi "leap"; then \
			echo "Submitting via git-obs (Leap branch detected)..."; \
			$(MAKE) --no-print-directory -f makefiles/leap-submit.mk submit-leap \
				TMP_DIR="$(TMP_DIR)" \
				SOURCE_DIR="$(SOURCE_DIR)" \
				PACKAGE_DIR="$(PACKAGE_DIR)" \
				OBS_PROJECT="$(OBS_PROJECT)" \
				OBS_DEV_PROJECT="$(OBS_DEV_PROJECT)" \
				OBS_API="$(OBS_API)" \
				GITEA_TOKEN="$(GITEA_TOKEN)" \
				DRY_RUN="$(DRY_RUN)"; \
		else \
			echo "Submitting to OBS (factory branch)..."; \
			$(MAKE) --no-print-directory -f makefiles/factory-submit.mk submit-factory \
				TMP_DIR="$(TMP_DIR)" \
				SOURCE_DIR="$(SOURCE_DIR)" \
				PACKAGE_DIR="$(PACKAGE_DIR)" \
				OBS_PROJECT="$(OBS_PROJECT)" \
				OBS_DEV_PROJECT="$(OBS_DEV_PROJECT)" \
				OBS_API="$(OBS_API)" \
				DRY_RUN="$(DRY_RUN)"; \
		fi; \
	fi

# Show status
.PHONY: status
status:
	@echo "Current Status:"
	@echo ""
	@echo "Git status:"
	@git status --short
	@echo ""
	@echo "Current branch:"
	@git branch --show-current
	@echo ""
	@echo "Recent commits:"
	@git log --oneline -5
	@echo ""
	@echo "Uncommitted changes:"
	@git diff --stat

# Clean temporary files
.PHONY: clean
clean:
	@echo ""
	@echo "Cleaning temporary files..."
	@if [ -d "$(TMP_DIR)" ]; then \
		rm -rf "$(TMP_DIR)" && \
		echo "  [OK] Removed $(TMP_DIR)"; \
	else \
		echo "  [INFO] No temporary directory to clean"; \
	fi
