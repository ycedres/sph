include ../makefiles/common.mk

FACTORY_BRANCH := factory
BRANCH := $(FACTORY_BRANCH)
STAGING_PROJECT := systemsmanagement:saltstack
TARGET_PROJECT := openSUSE:Factory
PACKAGE_NAME := salt

.PHONY: update-branch
update-branch:
	@git fetch origin $(BRANCH):$(BRANCH) 2>/dev/null || true
	@git switch --quiet --force-create $(BRANCH) --track origin/$(BRANCH)
	@$(MAKE) --no-print-directory update-package-files

.PHONY: submit-obs
submit-obs:
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "[DRY RUN] Would submit to $(STAGING_PROJECT) → $(TARGET_PROJECT)"; \
	else \
		$(MAKE) --no-print-directory submit-obs-impl; \
	fi

.PHONY: submit-obs-impl
submit-obs-impl:
	@OBS_WORK_DIR=$(TMPDIR)/obs && \
	mkdir -p $$OBS_WORK_DIR && \
	cd $$OBS_WORK_DIR && \
	osc -A $(OBS_API) co $(STAGING_PROJECT) $(PACKAGE_NAME) && \
	rsync -a --exclude=.git --exclude=Makefile --exclude=makefiles --exclude=.osc \
		$(REPO_DIR)/ $$OBS_WORK_DIR/$(STAGING_PROJECT)/$(PACKAGE_NAME)/ && \
	cd $$OBS_WORK_DIR/$(STAGING_PROJECT)/$(PACKAGE_NAME) && \
	osc addremove && \
	COMMIT_HASH=$$(cd $(TMPDIR)/salt && git rev-parse --short HEAD) && \
	osc ci -m "Update to openSUSE/salt@$$COMMIT_HASH" && \
	osc sr $(TARGET_PROJECT) -m "Update Salt to openSUSE/salt@$$COMMIT_HASH"
