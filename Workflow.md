# Packaging Workflow

Each participant focuses on their own area.

## Overall Flow

```mermaid
sequenceDiagram
    participant upstream as "Upstream (Salt & Extensions)"

    box Ion Squad
    participant ion as "Ion Squad Member"
    participant downstream as "github:openSUSE/salt"
    participant saltOrg as "src:salt org"
    participant bundleOrg as "src:saltbundle org"
    end
    
    box Uyui/SMLM Release Engineer
    participant releng as "Uyuni/SMLM Release Engineer"
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

## Ion Squad Flow
```mermaid
sequenceDiagram
    participant upstream as "Upstream (Salt & Extensions)"

    box Ion Squad
    participant ion as "Ion Squad"
    participant downstream as "github:openSUSE/salt"
    participant saltOrg as "src:salt org"
    participant bundleOrg as "src:saltbundle org"
    end
    
    upstream->>upstream: Release update
    ion->>upstream: pull changes
    alt Salt
        ion->>downstream: create PR with changelog entries <br/>(via rpmchangelogs)
        ion->>downstream: review & merge PR 
        Note over ion,saltOrg: Automated with a jenkins job
        saltOrg->>ion: Check out salt package git
        ion->>saltOrg: make update
        ion->>bundleOrg: update venv-salt-minion ("main" branch)
    else Salt Bundle Dependency
        ion->>bundleOrg: update dependency ("main" branch)
    else Salt Extension
        ion->>saltOrg: update saltext package git ("main" branch)
    end
    ion->>saltOrg: check testsuite results
```

## Examples

### SUSE Multi-Linux Manager Maintenance Update

Salt, Salt Bundle, and Salt Extension packages are up to date in `src.opensuse.org/salt/*`
and `src.opensuse.org/saltbundle/*`. The only missing step is to pull these updates into
`src.suse.de/galaxy/*` and prepare the Maintenance Update.

### SUSE Linux Enterprise Salt Maintenance Update


