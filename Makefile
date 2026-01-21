##
# Update Salt
#
# @file
# @version 0.1
#
# Assumptions:
# 1. There is one branch in the Package-Git per maintained code stream
# 2. openSUSE/salt contains one distinct changelog file per maintained code stream
#
# The approach taken updates one code stream / branch after another. A potential
# improvement would be to compute different make targets, one for each branch, and execute
# them in parallel. Such an approach needs to use different git checkouts or git worktrees
# to not mix code streams.
#

## Public Variables
# DEBUG - no default
BRANCHES ?= $(shell git branch -l | tr -d '[:blank:]*')
SALT_VERSION ?= 3006.0
MSG ?= "Update Salt package git"

## Internal Variables


# The variable below uses the "Splitting without adding whitespace trick".
# By default make replaces '\\n' with a single space. Using '$\\n' removes the space.
# See `info make 'Splitting Lines'` for more information.

# comma-separated list of files to extract, expanded by the shell's Pathname expansion
# usage: pkg/suse/{$(pkg_suse_files)}
pkg_suse_files := README.SUSE,_multibuild,salt.spec,update-documentation.sh$\
                  ,transactional_update.conf,salt-tmpfiles.d,html.tar.bz2

# Save the used makefile to pass it to sub-make invocations later
this_file := $(lastword $(MAKEFILE_LIST))
sub_make_flags := -f $(this_file)

# Pass --no-print-directory to sub-make when DEBUG is not set
ifndef DEBUG
sub_make_flags += --no-print-directory
endif

## "Shell Functions"
# usage: $(SHELL) -c "$(name-of-function)"
define git_maybe_commit_push
git status --porcelain | grep '.' >/dev/null 2>&1 && \
(git add . && \
 git commit --message $(MSG) && \
 git push) || true
endef

## Targets

.PHONY: update-salt-all
update-salt-all:
	@echo "Updating all Salt branches: $(patsubst %,'%', $(BRANCHES))"
	@$(foreach branch,$(BRANCHES),$\
	    $(MAKE) $(sub_make_flags) update-salt BRANCH=$(branch);)

.PHONY: update-salt
update-salt:
	$(if $(value BRANCH),,$(error Must set BRANCH))
	@echo "Updating $(BRANCH)"
	@git switch $(BRANCH)
	@$(MAKE) $(sub_make_flags) salt-subdir
	@$(MAKE) $(sub_make_flags) extract-files
# TODO: fix spec in openSUSE/salt repository
	sed -i '/^Url:.*/a#!CreateArchive: salt' salt.spec
	$(SHELL) -c "$(git_maybe_commit_push)"

# Replace salt/ subdir with a fresh git clone, then delete its .git directory
.PHONY: salt-subdir
salt-subdir:
	$(if $(value SALT_VERSION),,$(error Must set SALT_VERSION))
	rm -rf salt/
	git clone --branch "openSUSE/release/$(SALT_VERSION)" https://github.com/openSUSE/salt
	rm -rf salt/.git/

.PHONY: extract-files
# TODO: drop the <branch> directory in favor of <branch>.changes
extract-files:
	$(if $(value BRANCH),,$(error Must set BRANCH))
	cp salt/pkg/suse/{$(pkg_suse_files)} .
	cp salt/pkg/suse/changelogs/$(BRANCH)/salt.changes .

# end
