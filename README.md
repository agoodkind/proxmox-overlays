# Proxmox VE permission overlays

This repository adds narrow privileges to Proxmox VE. A non-root API token can then do one specific operation on one guest or one ACME account.

## What the overlay adds

Stock Proxmox VE restricts these operations to `root@pam`. The overlay adds a privilege for each one:

- `VM.Config.Nesting` changes the `nesting` flag of a container.
- `VM.Config.Keyctl` changes the `keyctl` flag of a container.
- `VM.Config.Vsock` enables a virtio vsock device on a VM. The guest CID equals the VM ID.
- `Sys.ACME.Account.Audit`, `Create`, `Modify`, and `Remove` read, register, update, and remove one named ACME account.

The [permission reference](docs/permissions.md) lists the ACL path and the API method for each privilege.

## How it works

The `patches` directory has one patch for each of four Proxmox components: `pve-access-control`, `pve-container`, `qemu-server`, and `pve-manager`. Each patch is the signed commit on the `overlays` branch of the `agoodkind` fork of that component. The patch header records the fork commit, and the last lines record the upstream base commit. Together the patches change seven Perl modules.

`pve-overlay` reads each packaged module from `/usr/share/perl5`, applies the patch, and writes the result to `/etc/perl`. Debian Perl searches `/etc/perl` before `/usr/share/perl5`, also in taint mode. Every Proxmox service and command loads the patched copy. `pve-overlay` does not write to packaged files.

A dpkg hook runs `pve-overlay apply` after each package operation. The hook builds new copies from the upgraded modules. When a patch does not apply to an upgraded module, the hook deletes all patched copies and Proxmox runs the packaged modules.

## Use it on a node

Run these commands as `root` from a copy of this repository on the node. The dpkg hook runs the script from that path. Run `./pve-overlay apply` again after moving the copy.

1. Run `./pve-overlay check` to test that every patch applies to the installed packages.
2. Run `./pve-overlay apply`. The command writes the patched copies, installs the dpkg hook, and restarts `pvedaemon`, `pveproxy`, `pvestatd`, `pvescheduler`, and `pve-ha-lrm`.
3. Run `./pve-overlay status`. Each line must show `current`.

A host can also have the files without a repository copy: the script at `/usr/local/sbin/pve-overlay` and each patch at `/usr/local/share/pve-overlay-<component>.patch`. The script reads the patches there when no `patches` directory sits beside it. OpenTofu declares the files this way in `agoodkind/configs`.

To return to packaged modules, run `./pve-overlay remove`. Packaged `qemu-server` deletes the `vsock` line from a VM config when it rewrites that config.

## Create a scoped token

The example grants one token the right to change `nesting` on container 101.

1. Create a role: `pveum role add CtNesting --privs "VM.Config.Nesting VM.Audit"`.
2. Create a user: `pveum user add svc-nesting@pve`.
3. Create a token with privilege separation: `pveum user token add svc-nesting@pve deploy --privsep 1`. Proxmox prints the secret once.
4. Grant the role to the user: `pveum acl modify /vms/101 --users svc-nesting@pve --roles CtNesting`.
5. Grant the role to the token: `pveum acl modify /vms/101 --tokens 'svc-nesting@pve!deploy' --roles CtNesting`.

Both grants are required. The token cannot change another option or another guest.

## Drift check

The `drift` workflow runs daily, on each pull request, and on each push to `main`. It runs `pve-overlay verify` against the newest published Proxmox VE packages from the stable and test repositories. `verify` applies the patches and loads each patched module in a taint-mode Perl process. A failed run means a patch needs a rebase in its fork.

The packages are installed in a container image in GHCR, built from `image/Dockerfile`. The image tag includes a hash of the Proxmox package index. The workflow builds a new image only when Proxmox publishes a package.

To update a patch after a rebase, run `git format-patch -1 --base=<upstream commit> --output=<patch file>` on the `overlays` branch of the fork.
