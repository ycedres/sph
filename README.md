# sph - Salt Packaging Helpers

The helpers in this repository will be moved to the [canonical Salt package-git repository](https://src.opensuse.org/pool/salt) when the transition is finished. They are developed here for the time being.

## Helpers

- `Makefile` with targets `update`. Takes `BRANCHES=` for a space-delimited list
  of branches to update. Defaults to all local git branches
- `populate-pkg-suse` [`bb`](https://babashka.org/) script to create the
  `pkg/suse/` directory in an https://github.com/openSUSE/salt checkout from
  scratch.
