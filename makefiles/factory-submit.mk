# Factory-specific OBS submission
# Submit request from OBS_DEV_PROJECT to OBS_PROJECT

SHELL := /bin/bash
.SHELLFLAGS := -e -u -o pipefail -c

.PHONY: submit-factory
submit-factory:
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "  [DRY RUN] Would submit request to OBS:"; \
		echo "    Source: $(OBS_DEV_PROJECT)"; \
		echo "    Target: $(OBS_TARGET_PROJECT)"; \
	else \
		$(MAKE) --no-print-directory submit-factory-impl; \
	fi

.PHONY: submit-factory-impl
submit-factory-impl:
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
	echo "  Creating submit request..." && \
	SR_OUTPUT=$$(osc -A $(OBS_API) sr -m "$$COMMIT_MSG" $(OBS_TARGET_PROJECT) 2>&1) && \
	SR_ID=$$(echo "$$SR_OUTPUT" | grep -oP 'created request id \K[0-9]+') && \
	if [ -n "$$SR_ID" ]; then \
		echo "  [OK] Submit request created: #$$SR_ID"; \
		echo ""; \
		echo "==========================================="; \
		echo "Request ID: $$SR_ID"; \
		echo "==========================================="; \
	else \
		echo "  [OK] Submit request created (ID not parsed)"; \
		echo "$$SR_OUTPUT"; \
	fi
