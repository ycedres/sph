# Leap-specific OBS submission via git-obs PR
# Creates PR from OBS_DEV_PROJECT to OBS_PROJECT

SHELL := /bin/bash
.SHELLFLAGS := -e -u -o pipefail -c

.PHONY: submit-leap
submit-leap:
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "  [DRY RUN] Would create PR via git-obs:"; \
		echo "    Source: $(OBS_DEV_PROJECT)"; \
		echo "    Target: $(OBS_TARGET_PROJECT)"; \
	else \
		$(MAKE) --no-print-directory submit-leap-impl; \
	fi

.PHONY: submit-leap-impl
submit-leap-impl:
	@OBS_WORK_DIR=$(TMP_DIR)/obs && \
	mkdir -p $$OBS_WORK_DIR && \
	cd $$OBS_WORK_DIR && \
	echo "  Checking out $(OBS_DEV_PROJECT) from OBS..." && \
	osc -A $(OBS_API) co $(OBS_DEV_PROJECT) && \
	echo "  Syncing files..." && \
	rsync -a --exclude=.git --exclude=Makefile* --exclude=makefiles --exclude=.osc --exclude=docs \
		$(PACKAGE_DIR)/ $$OBS_WORK_DIR/$(OBS_DEV_PROJECT)/ && \
	cd $$OBS_WORK_DIR/$(OBS_DEV_PROJECT) && \
	osc addremove && \
	COMMIT_HASH=$$(cd $(SOURCE_DIR) && git rev-parse --short HEAD) && \
	COMMIT_MSG="Update to ycedres/salt-1@$$COMMIT_HASH" && \
	echo "  Committing to OBS..." && \
	osc ci -m "$$COMMIT_MSG" && \
	echo "  Creating PR via git-obs..." && \
	if [ -n "$(GITEA_TOKEN)" ]; then \
		PR_OUTPUT=$$(git-obs -q -G $(GITEA_TOKEN) pr create $(OBS_TARGET_PROJECT) 2>&1) && \
		PR_ID=$$(echo "$$PR_OUTPUT" | grep -oP 'PR #\K[0-9]+' || echo "$$PR_OUTPUT" | grep -oP '#\K[0-9]+') && \
		if [ -n "$$PR_ID" ]; then \
			echo "  [OK] PR created: #$$PR_ID"; \
			echo ""; \
			echo "==========================================="; \
			echo "PR ID: $$PR_ID"; \
			echo "==========================================="; \
		else \
			echo "  [OK] PR created (ID not parsed)"; \
			echo "$$PR_OUTPUT"; \
		fi; \
	else \
		echo "  [ERROR] GITEA_TOKEN not set. Cannot create PR."; \
		echo "  Set GITEA_TOKEN environment variable or pass it to make."; \
		exit 1; \
	fi
