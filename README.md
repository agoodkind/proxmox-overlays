# Proxmox VE permission overlays

This repository adds narrow privileges to Proxmox VE. A non-root API token can then do one specific operation on one guest, host, or ACME account.

## What the overlay adds

Stock Proxmox VE restricts these operations to `root@pam`. The overlay adds a privilege for each one:

- `VM.Config.Nesting` changes the `nesting` flag of a container.
- `VM.Config.Keyctl` changes the `keyctl` flag of a container.
- The container API requires `VM.Config.BPFDelegate` privileges to change `bpfdelegate` on an unprivileged container. Each privilege authorizes one BPF command, map type, program type, or attach type.
- `VM.Config.Vsock` enables a virtio vsock device on a VM. The guest CID equals the VM ID.
- `VM.Config.HostNIC` permits changes to a container's `hostnic0` through `hostnic9` options. Changes also require `Sys.HostNIC.Use` for each host interface in the old and new values.
- `VM.Guest.Exec`, `VM.Guest.FileRead`, and `VM.Guest.FileWrite` authorize command execution, file reads, and file writes in containers as root and in VMs through the QEMU guest agent.
- `Sys.ACME.Account.Audit`, `Create`, `Modify`, and `Remove` read, register, update, and remove one named ACME account.
- Six `Sys.ACME.Plugin` privileges read, add, change, and delete one DNS plugin. The stored credentials have one privilege for reads and one for writes.
- `Sys.ACME.Certificate.Order`, `Renew`, and `Revoke` manage the certificate of one node.
- Four `Sys.ACME.Config` privileges read and change only the ACME options of one node.
- `Sys.KernelModules.Audit` reads one node's persistent kernel module list. `Sys.KernelModules.Modify` sets the list and loads allowlisted modules.
- `Sys.SRIOV.Audit` reads a node's SR-IOV configuration and current virtual functions. `Sys.SRIOV.Modify` declares and removes virtual functions.
- Host configuration methods verify trusted builds and install files within a target policy. Separate secret fields support rotation without rebuilding the configuration archive.

The [permission reference](docs/permissions.md) lists the ACL path and the API method for each privilege.

## How it works

`pve-overlay` reads each packaged module from `/usr/share/perl5`, applies the patch, and writes the result to `/etc/perl`. Debian Perl searches `/etc/perl` before `/usr/share/perl5`, also in taint mode. Every Proxmox service and command loads the patched copy. `pve-overlay` does not write to packaged files.

The API proxy removes backend connection headers before it builds a public response. It preserves content encoding and closes connections for streamed replies and replies without body framing.

`pve-overlay` records every installed path in `/var/lib/pve-overlay/installed`. `apply` deletes a recorded path that the current patches do not produce, for example after a rollback to an older patch set, unloads a deleted AppArmor profile, and restarts the units. `remove` deletes every recorded path, and `status` prints `orphan` for a recorded path that the current patches do not produce.

`pve-overlay` installs AppArmor profiles and the SR-IOV boot files from `overlay-root/<path>` at `/<path>`. It loads installed profiles with `apparmor_parser` and reloads systemd after installing or removing the SR-IOV service and its dependencies. Remove saved SR-IOV declarations through the node API before removing boot restoration.

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

The `drift` workflow runs daily, on each pull request, and on each push to `main`. It runs `pve-overlay verify` against the newest published Proxmox VE packages from the stable and test repositories. `verify` applies the patches and loads each patched module in a taint-mode Perl process. The job also runs `test-host-artifacts`, `test-host-secrets`, `test-host-units`, `test-host-artifacts-attestation`, and `test-host-artifacts-installed-source` against reconstructed pve-manager source in a disposable container, then removes that container. If a patch fails to apply, update it here against the upstream source for the affected package.

The workflow installs the packages in a container image in GHCR and builds the image from `image/Dockerfile`. The image tag is `<component>-<hash of the Proxmox package index>-<hash of image/Dockerfile>`. The workflow builds a new image when Proxmox publishes a package or when `image/Dockerfile` changes. Otherwise, the workflow pulls the existing image from GHCR.

## Select a compatibility patch

`pve-overlay` reads the top level of the [patches directory](patches/). Select each compatibility patch independently. Install it under the name of the default patch it replaces.

| Package | Version or package check | Patch |
| --- | --- | --- |
| pve-manager | 9.2.24 checks `Sys.Modify` at `/nodes/{node}` | [Compatibility certificate patch](patches/compat/pve-manager-acme-node.patch) |
| pve-manager | 9.2.26 checks `Sys.Modify` at `/nodes/{node}/certificates` | [Default certificate patch](patches/pve-manager-acme.patch) |
| pve-container | 6.1.15 through 6.1.21 | [Compatibility container patch](patches/compat/pve-container-6.1.21.patch) |
| pve-container | 6.1.22 through 6.1.24 | [Default container patch](patches/pve-container.patch) |
| qemu-server | 9.2.10 through 9.2.14 | [Compatibility QEMU patch](patches/compat/qemu-server-9.2.14.patch) |
| qemu-server | 9.2.15 through 9.2.20 | [Default QEMU patch](patches/qemu-server.patch) |

## Regenerate an overlay patch

Reconstruct the source from a public upstream repository and the patch committed here. Clone the upstream repository into a temporary directory. Run the commands below from that directory.

| Upstream repository | Patch | Upstream revision |
| --- | --- | --- |
| [pve-manager](https://github.com/proxmox/pve-manager) | Manager and default certificate | `41a0e2e09b9e6f9da5a19b580a38db2b45ece97b` |
| pve-manager | Compatibility certificate | `66bc407c6d90a67aa15caed394bb294af174b6e1` |
| [pve-access-control](https://github.com/proxmox/pve-access-control) | Access control | `dff26b458651b4e1141ff0a41a296d2904b16228` |
| [pve-http-server](https://github.com/proxmox/pve-http-server) | HTTP server | `5c9e4ea773364bdb7ae0e2faec5750fe58129a47` |
| [pve-container](https://github.com/proxmox/pve-container) | Compatibility container | `de0ddd657525ef5c4bb0fd5783d0f585aa9034c1` |
| pve-container | Default container | `96021ad7dbc4ec8e618de880d59d2a12a9c8c0f1` |
| [qemu-server](https://github.com/proxmox/qemu-server) | Compatibility QEMU | `a7b4240bba1dd493d6c76daad1e70af62b2ebcc8` |
| qemu-server | Default QEMU | `91253ed548ea6bf9fbe8a3b0aa691933e52f8ed7` |

1. Run `git switch --detach <upstream-revision>`. For the access control patch, also restore the exact module revision before saving the base tree.

   ```sh
   git restore --source=eb08cdfc72371c4d63f371d81f8d25232524e711 --staged --worktree src/PVE/AccessControl.pm
   ```

2. Set `patch` to the absolute path to the committed patch in this repository. Run `git write-tree` and assign the printed tree ID to `base_tree`. Run `git apply --index "$patch"` to apply the patch to the source and index.

3. Edit the reconstructed source. Format new Perl files with [proxmox-perltidy](https://git.proxmox.com/?p=proxmox-perltidy.git). For existing Perl files, run it on a temporary copy and transfer the formatter changes for the edited blocks. Format changes shared by the default and compatibility variants against each base.

4. Stage the edits and regenerate the patch.

   ```sh
   git add -A
   git diff --cached --check "$base_tree"
   git diff --cached --binary --output="${patch}.new" "$base_tree"
   ```

   Reconstruct the manager and certificate patches separately. The certificate patches contain only `PVE/API2/ACME.pm`. For access control, omit the final context line for `/nodes/{node}/certificates` from the `check_path` hunk and subtract one from both hunk line counts. That line differs across supported packages.

5. Apply the regenerated patch to a fresh copy of the same base. Review the diff and replace the committed patch. In a disposable Proxmox package environment, select the matching distribution patches and run `/path/to/proxmox-overlays/pve-overlay verify --no-system`. Repeat verification for each affected variant. Commit the patch in this repository.
