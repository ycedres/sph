SHELL := /bin/bash
.SHELLFLAGS := -e -u -o pipefail -c

SALT_REPO ?= https://github.com/openSUSE/salt
SALT_BRANCH ?= openSUSE/release/3006.0
OBS_API ?= https://api.opensuse.org
GIT_PUSH ?= 1
DRY_RUN ?= 0

TMPDIR := $(shell mktemp -d)
REPO_DIR := $(CURDIR)

pkg_suse_files := README.SUSE,_multibuild,salt.spec,update-documentation.sh,\
  transactional_update.conf,salt-tmpfiles.d,html.tar.bz2

.PHONY: validate-common
validate-common:
	@command -v git >/dev/null 2>&1 || (echo "ERROR: git not found" && exit 1)
	@test -f salt.spec || (echo "ERROR: salt.spec not found" && exit 1)

.PHONY: fetch-source
fetch-source:
	@git clone --quiet --depth 1 --branch $(SALT_BRANCH) $(SALT_REPO) $(TMPDIR)/salt

.PHONY: update-package-files
update-package-files:
	@rm -rf salt
	@cp -r $(TMPDIR)/salt .
	@rm -rf salt/.git*
	@cp salt/pkg/suse/{$(pkg_suse_files)} .
	@cp salt/pkg/suse/changelogs/$(BRANCH).changes salt.changes

.PHONY: commit-changes
commit-changes:
	@git add -A
	@if git status --porcelain --untracked-files=no | grep -q "."; then \
		if [ -n "$(MSG)" ]; then \
			COMMIT_MSG="$(MSG)"; \
		else \
			COMMIT_HASH=$$(cd $(TMPDIR)/salt && git rev-parse --short HEAD); \
			COMMIT_MSG="Update to openSUSE/salt@$$COMMIT_HASH"; \
		fi; \
		if [ "$(DRY_RUN)" = "1" ]; then \
			echo "[DRY RUN] Would commit with message: $$COMMIT_MSG"; \
			git diff --cached --stat; \
		else \
			git commit -m "$$COMMIT_MSG" && \
			echo "[OK] Committed: $$COMMIT_MSG"; \
		fi; \
	fi

.PHONY: push-changes
push-changes:
	@if [ "$(GIT_PUSH)" = "1" ] && git rev-list --count @{u}..HEAD 2>/dev/null | grep -q "^[1-9]"; then \
		if [ "$(DRY_RUN)" = "1" ]; then \
			echo "[DRY RUN] Would push to origin/$(BRANCH)"; \
		else \
			git push origin $(BRANCH); \
		fi; \
	fi

.PHONY: clean
clean:
	@rm -rf $(TMPDIR)
