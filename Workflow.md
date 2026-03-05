# Packaging Workflow

Each participant focuses on their own area.

## Sequence Diagram

```mermaid
sequenceDiagram
    participant upstream as "Upstream (Salt & Extensions)"

    box openSUSE Salt Maintainer
    participant ion as "Ion Squad"
    participant downstream as "github:openSUSE/salt"
    participant saltOrg as "src:salt org"
    participant bundleOrg as "src:saltbundle org"
    end
    
    box Uyui/SMLM Release Engineer
    participant releng as "Uyuni/SMLM Release Engineers"
    participant galaxyOrg as "src:galaxy org"
    end

    upstream->>upstream: Release update
    ion->>upstream: pull changes
    alt Salt
        ion->>downstream: update release branch
        ion->>saltOrg: update salt package git (one branch per code stream)
        ion->>bundleOrg: update venv-salt-minion ("main" branch)
    else Salt Bundle Dependency
        ion->>bundleOrg: update dependency ("main" branch)
    else Salt Extension
        ion->>saltOrg: update saltext package git ("main" branch)
    end
    ion->>saltOrg: check testsuite results
    
    releng->>saltOrg: pull package updates
    releng->>bundleOrg: pull package updates
    releng->>galaxyOrg: push package updates
```

## Examples

### SUSE Multi-Linux Manager Maintenance Update

Salt, Salt Bundle, and Salt Extension packages are up to date in `src.opensuse.org/salt/*`
and `src.opensuse.org/saltbundle/*`. The only missing step is to pull these updates into
`src.suse.de/galaxy/*` and prepare the Maintenance Update.

### SUSE Linux Enterprise Salt Maintenance Update


