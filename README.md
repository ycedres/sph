# sph - Salt Packaging Helpers

These helpers help us packaging Salt and Salt Extensions. We have two approaches for packaging, one for Salt and another for Salt Extensions. Both approaches manage the packaging sources in git repositories in the [salt org](https://src.opensuse.org/salt/).

## Salt Packaging: Embedded

For Salt, we maintain our own fork [_openSUSE/salt_](https://github.com/openSUSE/salt). In this fork we maintain all files required for packaging: configuration defaults, RPM Specfile, changelogs for different code streams, etc. Pull requests to _openSUSE/salt_ update these files as needed. A special mention is required for the changelogs. We have differing changelogs, but in general a pull request should update all of them. To help with this, a script `rpmchangelogs` is part of _openSUSE/salt_. We did not put it in this repository to make it easily accessible for contributors.

### Fan out

In [_salt package git_](https://src.opensuse.org/salt/salt) we have one branch per code stream. In this branch, the corresponding changelog in present the root directory. _openSUSE/salt_ is a subdirectory in _salt package git_. We fan out from one branch in _openSUSE/salt_ to _n_ number of branches in _salt package git_. Most of the time, these branches' only difference is in _salt.changes_. While we upgrade to a newer Salt version, the _factory_ branch could be widely different from the rest.

## Salt Extension Packaging: Wrapped

Salt Extensions may or may not be maintained by us. Salt Extensions not maintained by us can't use the "Embedded" approach we use for Salt. For consistency, we want to use the same approach for all Salt Extensions. These are new packages and don't require multiple branches. They will all have the same changelog and we don't expect major version upgrades that need to be staged. In case we do need additional branches, we can always add them.

## Helpers

- `Makefile` with targets `update`. Takes `BRANCHES=` for a space-delimited list
  of branches to update. Defaults to all local git branches
- `populate-pkg-suse` [`bb`](https://babashka.org/) script to create the
  `pkg/suse/` directory in an https://github.com/openSUSE/salt checkout from
  scratch.
