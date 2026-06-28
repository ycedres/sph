# Leap-specific Gitea PR creation
# Creates PR from GITEA_PACKAGE_GIT (source) to GITEA_TARGET_REPO (target) using git-obs

SHELL := /bin/bash
.SHELLFLAGS := -e -u -o pipefail -c

SOURCE_OWNER ?= $(firstword $(subst /, ,$(GITEA_PACKAGE_GIT)))
SOURCE_REPO  ?= $(lastword $(subst /, ,$(GITEA_PACKAGE_GIT)))
TARGET_OWNER ?= $(firstword $(subst /, ,$(GITEA_TARGET_REPO)))

$(info DEBUG: leap-submit.mk loaded)
$(info DEBUG: Available targets: submit-leap)

.PHONY: submit-leap
submit-leap:
	@echo "DEBUG: submit-leap target called"
	@echo "  DRY_RUN=$(DRY_RUN)"
	@echo "  BRANCH=$(BRANCH)"
	@COMMIT_HASH=$$(cd $(SOURCE_DIR) 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo "abc1234"); \
	PR_TITLE="Update $(BRANCH) to ycedres/salt-1@$$COMMIT_HASH"; \
	PR_DESCRIPTION="Automated update from GitHub ycedres/salt-1 repository."; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		echo "  [DRY RUN] Would create Gitea PR via git-obs:"; \
		echo "    Source: $(GITEA_PACKAGE_GIT) (branch: $(BRANCH))"; \
		echo "    Target: $(GITEA_TARGET_REPO) (branch: $(BRANCH))"; \
		echo "    Server: $(GITEA_SERVER)"; \
		echo "    Command: git-obs -G opensuse pr create --source-owner \"$(SOURCE_OWNER)\" --source-repo \"$(SOURCE_REPO)\" --source-branch \"$(BRANCH)\" --target-owner \"$(TARGET_OWNER)\" --target-branch \"$(BRANCH)\" --title \"$$PR_TITLE\" --description \"$$PR_DESCRIPTION\""; \
	else \
		if [ -z "$(GITEA_TOKEN)" ]; then \
			echo "  [ERROR] GITEA_TOKEN not set. Cannot create PR."; \
			echo "  Set GITEA_TOKEN environment variable or pass it to make."; \
			exit 1; \
		fi; \
		echo "  Creating Gitea PR via git-obs..."; \
		echo "    Title: $$PR_TITLE"; \
		echo "    From: $(GITEA_PACKAGE_GIT):$(BRANCH)"; \
		echo "    To:   $(GITEA_TARGET_REPO):$(BRANCH)"; \
		echo "  DEBUG: Setting up git-obs login..."; \
		if ! git-obs login list | grep -q "src.opensuse.org"; then \
			echo "  DEBUG: Adding git-obs login entry..."; \
			GITEA_TOKEN=$(GITEA_TOKEN) git-obs login add opensuse \
				--url https://$(GITEA_SERVER) \
				--token "$(GITEA_TOKEN)" \
				--set-as-default >/dev/null 2>&1 || true; \
		fi; \
		echo "  DEBUG: Running git-obs pr create with:"; \
		echo "    --source-owner \"$(SOURCE_OWNER)\""; \
		echo "    --source-repo \"$(SOURCE_REPO)\""; \
		echo "    --source-branch \"$(BRANCH)\""; \
		echo "    --target-owner \"$(TARGET_OWNER)\""; \
		echo "    --target-branch \"$(BRANCH)\""; \
		echo "  DEBUG: Command: git-obs -G opensuse pr create --source-owner \"$(SOURCE_OWNER)\" --source-repo \"$(SOURCE_REPO)\" --source-branch \"$(BRANCH)\" --target-owner \"$(TARGET_OWNER)\" --target-branch \"$(BRANCH)\" --title \"$$PR_TITLE\" --description \"$$PR_DESCRIPTION\""; \
		if PR_OUTPUT=$$(git-obs -G opensuse pr create \
		    --source-owner "$(SOURCE_OWNER)" \
			--source-repo "$(SOURCE_REPO)" \
			--source-branch "$(BRANCH)" \
			--target-owner "$(TARGET_OWNER)" \
			--target-branch "$(BRANCH)" \
			--title "$$PR_TITLE" \
			--description "$$PR_DESCRIPTION" 2>&1); then \
			echo "  DEBUG: git-obs succeeded"; \
			echo "  DEBUG: Output: $$PR_OUTPUT"; \
		else \
			GIT_OBS_EXIT=$$?; \
			echo "  [ERROR] git-obs failed with exit code: $$GIT_OBS_EXIT"; \
			echo "  Output: $$PR_OUTPUT"; \
			exit $$GIT_OBS_EXIT; \
		fi; \
		PR_ID=$$(echo "$$PR_OUTPUT" | grep -oP 'PR #\K[0-9]+' || echo "$$PR_OUTPUT" | grep -oP '#\K[0-9]+' || echo "$$PR_OUTPUT" | grep -oP 'pull/\K[0-9]+' || true); \
		if [ -n "$$PR_ID" ]; then \
			echo "  [OK] PR created: #$$PR_ID"; \
			echo ""; \
			echo "==========================================="; \
			echo "PR ID: $$PR_ID"; \
			echo "PR URL: https://$(GITEA_SERVER)/$(GITEA_TARGET_REPO)/pulls/$$PR_ID"; \
			echo "==========================================="; \
		else \
			echo "  [OK] PR created (ID not parsed)"; \
			echo "$$PR_OUTPUT"; \
		fi; \
	fi
