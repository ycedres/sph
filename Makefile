#### Update Salt Package Git
##
##
## Assumptions:
## 1. There is one branch in the Package-Git per maintained code stream
## 2. openSUSE/salt contains one changelog file per maintained code stream
##
## NOTE: The approach taken updates one code stream / branch after another. A potential
# improvement would be to compute different make targets, one for each branch, and execute
# them in parallel. Such an approach needs to use different git checkouts or git worktrees
# to not mix code streams.

## Public Variables
# DEBUG - no default
# MSG - no default
BRANCHES ?= $(shell git branch -l | tr -d '[:blank:]*')
SALT_VERSION ?= 3006.0
SALT_REPO ?= https://github.com/openSUSE/salt
SALT_BRANCH ?= openSUSE/release/$(SALT_VERSION)

## Internal Variables
SHELL=/bin/bash

# The variable below uses the "Splitting without adding whitespace trick".
# By default make replaces '\\n' with a single space. Using '$\\n' removes the space.
# See `info make 'Splitting Lines'` for more information.

# comma-separated list of files to extract, expanded by the shell's Pathname expansion
# usage: pkg/suse/{$(pkg_suse_files)}
pkg_suse_files := README.SUSE,_multibuild,salt.spec,update-documentation.sh$\
                  ,transactional_update.conf,salt-tmpfiles.d,html.tar.bz2

# comma-separated list of files tracked in the package git repository, expanded
# by the shell's Pathname expansion
# usage: {$(git_tracked_files)}
git_tracked_files := $(pkg_suse_files),salt,salt.changes

# Save the used makefile to pass it to sub-make invocations later
this_file := $(lastword $(MAKEFILE_LIST))
sub_make_flags := -f $(this_file)

# Pass --no-print-directory to sub-make when DEBUG is not set
ifndef DEBUG
sub_make_flags += --no-print-directory
endif

## "Shell Functions"
# usage: $(SHELL) -c '$(function-name)'

define git_maybe_commit
git add {$(git_tracked_files)}; \
if git status --porcelain --untracked-files=no | grep -q "."; \
then \
	git commit --message \
"$$([ -n "$(MSG)" ] && echo "$(MSG)"  || echo Update to openSUSE/salt@$$(cat .rev))" ;\
fi
endef

## Targets

# Update branches in $BRANCHES (default: all git branches)
.PHONY: update-branches
update-branches:
	@echo "Updating Salt branches: $(patsubst %,'%', $(BRANCHES))"
	@$(foreach branch,$(BRANCHES),$\
	    $(MAKE) $(sub_make_flags) update-ipml BRANCH=$(branch);)
	@rm -f .rev

# Update a single branch in Package git
.PHONY: update
update:
	$(if $(value BRANCH),,$(error Must set BRANCH))
	@$(MAKE) $(sub_make_flags) update-ipml
	@rm -f .rev

.PHONY: update-ipml
update-ipml:
	$(if $(value BRANCH),,$(error Must set BRANCH))
	@$(MAKE) $(sub_make_flags) salt-subdir
	@echo "Updating $(BRANCH)"
	@git switch $(BRANCH)
	@$(MAKE) $(sub_make_flags) extract-files
	@$(SHELL) -c '$(git_maybe_commit)'

# Replace salt/ subdir with a fresh git clone, then delete its .git directory
.PHONY: salt-subdir
salt-subdir:
	$(if $(value SALT_VERSION),,$(error Must set SALT_VERSION))
	@rm -rf salt/
	@git clone --depth 1 --branch $(SALT_BRANCH) $(SALT_REPO) salt/
	@cd salt && git rev-parse --short HEAD >../.rev
	@rm -rf salt/.git/

# Copy files out of salt/ subdir
.PHONY: extract-files
extract-files:
	$(if $(value BRANCH),,$(error Must set BRANCH))
	cp salt/pkg/suse/{$(pkg_suse_files)} .
	cp salt/pkg/suse/changelogs/$(BRANCH).changes salt.changes

html.tar.bz2:
	sh update-documentation.sh salt-maintainers@suse.de --without-sphinx
