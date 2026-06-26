# Leap-specific Gitea PR creation
# Creates PR from GITEA_PACKAGE_GIT (source) to GITEA_TARGET_REPO (target) using git-obs

SHELL := /bin/bash
.SHELLFLAGS := -e -u -o pipefail -c

.PHONY: submit-leap
submit-leap:
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "  [DRY RUN] Would create Gitea PR via git-obs:"; \
		echo "    Source: $(GITEA_PACKAGE_GIT) (branch: $(BRANCH))"; \
		echo "    Target: $(GITEA_TARGET_REPO) (branch: $(BRANCH))"; \
		echo "    Server: $(GITEA_SERVER)"; \
	else \
		if [ -z "$(GITEA_TOKEN)" ]; then \
		echo "  [ERROR] GITEA_TOKEN not set. Cannot create PR."; \
		echo "  Set GITEA_TOKEN environment variable or pass it to make."; \
		exit 1; \
	fi; \
	COMMIT_HASH=$$(cd $(SOURCE_DIR) && git rev-parse --short HEAD); \
	PR_TITLE="Update $(BRANCH) to ycedres/salt-1@$$COMMIT_HASH"; \
	PR_DESCRIPTION="Automated update from GitHub ycedres/salt-1 repository."; \
	echo "  Creating Gitea PR via git-obs..."; \
	echo "    Title: $$PR_TITLE"; \
	echo "    From: $(GITEA_PACKAGE_GIT):$(BRANCH)"; \
	echo "    To:   $(GITEA_TARGET_REPO):$(BRANCH)"; \
	PR_OUTPUT=$$(git-obs -q -G $(GITEA_TOKEN) pr create \
		--target-repo $(GITEA_TARGET_REPO) \
		--title "$$PR_TITLE" \
		--description "$$PR_DESCRIPTION" 2>&1); \
	PR_ID=$$(echo "$$PR_OUTPUT" | grep -oP 'PR #\K[0-9]+' || echo "$$PR_OUTPUT" | grep -oP '#\K[0-9]+' || echo "$$PR_OUTPUT" | grep -oP 'pull/\K[0-9]+'); \
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
