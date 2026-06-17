include ../makefiles/common.mk

PACKAGE_NAME := salt
GIT_OBS_GITEA_LOGIN ?= $(GITEA_TOKEN)

.PHONY: update-branch
update-branch:
	@git fetch origin $(BRANCH):$(BRANCH) 2>/dev/null || true
	@git switch --quiet $(BRANCH)
	@git pull --quiet origin $(BRANCH)
	@UPDATE_BRANCH=update-$(BRANCH)-$(shell date +%Y%m%d-%H%M%S) && \
	git switch --quiet --force-create $$UPDATE_BRANCH && \
	$(MAKE) --no-print-directory update-package-files && \
	echo $$UPDATE_BRANCH > $(TMPDIR)/update_branch

.PHONY: push-changes
push-changes:
	@UPDATE_BRANCH=$$(cat $(TMPDIR)/update_branch) && \
	if [ "$(GIT_PUSH)" = "1" ] && git rev-list --count HEAD^..HEAD 2>/dev/null | grep -q "^[1-9]"; then \
		if [ "$(DRY_RUN)" = "1" ]; then \
			echo "[DRY RUN] Would push $$UPDATE_BRANCH"; \
		else \
			git push origin $$UPDATE_BRANCH; \
		fi; \
	fi

.PHONY: create-pr
create-pr:
	@UPDATE_BRANCH=$$(cat $(TMPDIR)/update_branch) && \
	COMMIT_HASH=$$(cd $(TMPDIR)/salt && git rev-parse --short HEAD) && \
	if [ "$(DRY_RUN)" = "1" ]; then \
		echo "[DRY RUN] Would create PR: $$UPDATE_BRANCH → $(BRANCH)"; \
	else \
		git-obs -q -G $(GIT_OBS_GITEA_LOGIN) pr create \
			--title "Update $(BRANCH) to openSUSE/salt@$$COMMIT_HASH" \
			--description "Automated update from GitHub openSUSE/salt repository."; \
	fi

.PHONY: submit-obs
submit-obs:
	@git switch --quiet $(BRANCH)
	@VERSION=$$(echo $(BRANCH) | sed 's/[Ll]eap-\([0-9]*\.[0-9]*\).*/\1/') && \
	if echo "$(BRANCH)" | grep -q '^leap-'; then \
		TARGET="openSUSE:Backports:SLE-$$VERSION"; \
	elif echo "$(BRANCH)" | grep -q '^Leap-'; then \
		TARGET="openSUSE:Leap:$$VERSION"; \
	fi && \
	if [ "$(DRY_RUN)" = "1" ]; then \
		echo "[DRY RUN] Would submit to $$TARGET"; \
	else \
		$(MAKE) --no-print-directory submit-obs-impl TARGET=$$TARGET; \
	fi

.PHONY: submit-obs-impl
submit-obs-impl:
	@OBS_WORK_DIR=$(TMPDIR)/obs && \
	STAGING_PROJECT=systemsmanagement:saltstack && \
	mkdir -p $$OBS_WORK_DIR && \
	cd $$OBS_WORK_DIR && \
	osc -A $(OBS_API) co $$STAGING_PROJECT $(PACKAGE_NAME) && \
	rsync -a --exclude=.git --exclude=Makefile --exclude=makefiles --exclude=.osc \
		$(REPO_DIR)/ $$OBS_WORK_DIR/$$STAGING_PROJECT/$(PACKAGE_NAME)/ && \
	cd $$OBS_WORK_DIR/$$STAGING_PROJECT/$(PACKAGE_NAME) && \
	osc addremove && \
	osc ci -m "Update $(BRANCH)" && \
	osc sr $(TARGET) -m "Update Salt for $(TARGET)"
