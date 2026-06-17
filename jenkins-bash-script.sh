#!/bin/bash
# Simplified Jenkins test script for Salt package updates
# Uses Makefile.simple for easy testing and understanding

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail

# =============================================================================
# Configuration - Development Environment
# =============================================================================

# Makefiles repository (contains Makefile.simple and makefiles/*.mk)
MAKEFILES_REPO="${MAKEFILES_REPO:-https://github.com/ycedres/sph.git}"
MAKEFILES_BRANCH="${MAKEFILES_BRANCH:-main}"

# Your development branches
GITEA_PACKAGE_GIT="${GITEA_PACKAGE_GIT:-ygutierrez/salt}"
GITEA_SERVER="${GITEA_SERVER:-src.opensuse.org}"

GITHUB_SOURCE_GIT="${GITHUB_SOURCE_GIT:-https://github.com/ycedres/salt-1}"
GITHUB_BRANCH="${GITHUB_BRANCH:-embed-packaging}"

OBS_DEV_PROJECT="${OBS_DEV_PROJECT:-home:ygutierrez:branches:home:ygutierrez:branches:systemsmanagement:saltstack/salt}"
OBS_PROJECT="${OBS_PROJECT:-home:ygutierrez:branches:systemsmanagement:saltstack}"
OBS_API="${OBS_API:-https://api.opensuse.org}"

# Target branch in package-git
BRANCH="${BRANCH:-factory}"

# Control flags
DRY_RUN="${DRY_RUN:-1}"      # Default to dry-run for safety
GIT_PUSH="${GIT_PUSH:-0}"     # Default to no push
OBS_SUBMIT="${OBS_SUBMIT:-0}" # Default to no OBS submit

# =============================================================================
# Get Gitea token
# =============================================================================

GITEA_TOKEN=$(grep --only-matching --perl-regexp "machine\\s+${GITEA_SERVER}\\s+login\\s+\\S+\\s+password\\s+\\K\\S+" ~/.netrc 2>/dev/null || echo "")

if [ -z "$GITEA_TOKEN" ]; then
    echo "ERROR: GITEA_TOKEN not found in ~/.netrc"
    echo "Add entry: machine ${GITEA_SERVER} login <user> password <token>"
    exit 1
fi

# =============================================================================
# Print configuration
# =============================================================================

echo "=========================================="
echo "Salt Package Update - Simple Test"
echo "=========================================="
echo "Makefiles:"
echo "  Repository: $MAKEFILES_REPO"
echo "  Branch: $MAKEFILES_BRANCH"
echo ""
echo "Source:"
echo "  GitHub: $GITHUB_SOURCE_GIT"
echo "  Branch: $GITHUB_BRANCH"
echo ""
echo "Target:"
echo "  Gitea: $GITEA_SERVER/$GITEA_PACKAGE_GIT"
echo "  Branch: $BRANCH"
echo ""
echo "OBS:"
echo "  Project: $OBS_PROJECT"
echo ""
echo "Flags:"
echo "  DRY_RUN:    $DRY_RUN"
echo "  GIT_PUSH:   $GIT_PUSH"
echo "  OBS_SUBMIT: $OBS_SUBMIT"
echo "=========================================="
echo ""

# =============================================================================
# Clone Makefiles repository
# =============================================================================

if [ -d "sph" ]; then
    echo "Removing existing sph directory..."
    rm -rf sph
fi

echo "Cloning Makefiles repository..."
git clone -q --branch "$MAKEFILES_BRANCH" "$MAKEFILES_REPO" sph

echo "Makefiles cloned:"
ls -la sph/*.mk sph/Makefile* 2>/dev/null || ls -la sph/
echo ""

# =============================================================================
# Clone package-git repository
# =============================================================================

if [ -d "salt" ]; then
    echo "Removing existing salt directory..."
    rm -rf salt
fi

echo "Cloning package-git repository..."
git clone -q "https://${GITEA_TOKEN}@${GITEA_SERVER}/${GITEA_PACKAGE_GIT}" salt

cd salt

# Checkout the target branch
echo "Checking out branch: $BRANCH"
git checkout -q "$BRANCH" 2>/dev/null || git checkout -q -b "$BRANCH"

# Copy Makefile from sph repository
echo "Copying Makefile from sph repository..."
if [ -f "../sph/Makefile" ]; then
    cp ../sph/Makefile .
    echo "  [OK] Copied Makefile"
else
    echo "  [ERROR] Makefile not found in sph repository!"
    exit 1
fi

# Copy makefiles directory if it exists
if [ -d "../sph/makefiles" ]; then
    cp -r ../sph/makefiles .
    echo "  [OK] Copied makefiles directory"
fi

# Show current state
echo ""
echo "Current branch: $(git branch --show-current)"
echo "Last commit: $(git log -1 --oneline)"
echo "Makefiles present: $(ls -1 Makefile makefiles/*.mk 2>/dev/null | tr '\n' ' ')"
echo ""

# =============================================================================
# Run the update
# =============================================================================

echo "=========================================="
echo "Running update workflow..."
echo "=========================================="
echo ""

make update \
    GITHUB_SOURCE_GIT="$GITHUB_SOURCE_GIT" \
    GITHUB_BRANCH="$GITHUB_BRANCH" \
    BRANCH="$BRANCH" \
    OBS_PROJECT="$OBS_PROJECT" \
    OBS_API="$OBS_API" \
    DRY_RUN="$DRY_RUN" \
    GIT_PUSH="$GIT_PUSH" \
    OBS_SUBMIT="$OBS_SUBMIT"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""

echo "Changes made:"
if [ -n "$(git status --short)" ]; then
    git status --short
else
    echo "  (no uncommitted changes)"
fi

echo ""
echo "Commits:"
git log --oneline -3

echo ""
echo "=========================================="
echo "Test complete!"
echo "=========================================="
echo ""

if [ "$DRY_RUN" = "1" ]; then
    echo "This was a DRY RUN - no actual changes were pushed."
    echo ""
    echo "To actually execute:"
    echo "  DRY_RUN=0 GIT_PUSH=1 $0"
fi

if [ "$GIT_PUSH" = "0" ]; then
    echo ""
    echo "Changes were not pushed to Gitea."
    echo ""
    echo "To push:"
    echo "  cd salt && make push GIT_PUSH=1"
fi

if [ "$OBS_SUBMIT" = "0" ]; then
    echo ""
    echo "Changes were not submitted to OBS."
    echo ""
    echo "To submit:"
    echo "  cd salt && make submit OBS_SUBMIT=1"
fi

# =============================================================================
# Cleanup
# =============================================================================

echo ""
echo "Cleaning up..."
cd ..
if [ -d "sph" ]; then
    rm -rf sph
    echo "Removed sph directory"
fi
echo "Done!"