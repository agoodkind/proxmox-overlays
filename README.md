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

`pve-overlay` reads each packaged module from `/usr/share/perl5`, applies its patches in filename order, and writes the result to `/etc/perl`. Each patch starts from the previous result for the same module. Debian Perl searches `/etc/perl` before `/usr/share/perl5`, also in taint mode. Every Proxmox service and command loads the patched copy. `pve-overlay` does not write to packaged files.

The API proxy removes backend connection headers before it builds a public response. It preserves content encoding and closes connections for streamed replies and replies without body framing.

`pve-overlay` records every installed path in `/var/lib/pve-overlay/installed`. `apply` deletes a recorded path that the current patches do not produce, for example after a rollback to an older patch set, unloads a deleted AppArmor profile, and restarts the units. `remove` deletes every recorded path, and `status` prints `orphan` for a recorded path that the current patches do not produce.

`pve-overlay` installs AppArmor profiles and the SR-IOV boot files from `overlay-root/<path>` at `/<path>`. It loads installed profiles with `apparmor_parser` and reloads systemd after installing or removing the SR-IOV service and its dependencies. Remove saved SR-IOV declarations through the node API before removing boot restoration.

An APT hook checks every patch against the proposed package files before installation. It accounts for modules that upgrades or removals delete. A conflict or an incomplete check stops the transaction and submits an email to root with the host, package versions, and error. Proxmox processes root mail through its configured notification matchers. Email delivery requires a working local mail service and an enabled email target.

A dpkg hook rebuilds the overlays after installation. Direct dpkg commands bypass the APT check. If a change bypasses that check and breaks a patch, the dpkg hook removes the incompatible copies. The APT check verifies patch application against archive contents. It does not execute package maintenance scripts or prove runtime compatibility.

## Use it on a node

Run these commands as `root` from a copy of this repository on the node. The dpkg hook runs the script from that path. Run `./pve-overlay apply` again after moving the copy.

1. Run `./pve-overlay check` to test that every patch applies to the installed packages.
2. Run `./pve-overlay apply`. The command writes the patched copies, installs the APT and dpkg hooks, and restarts `pvedaemon`, `pveproxy`, `pvestatd`, `pvescheduler`, and `pve-ha-lrm`.
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

The `drift` workflow runs daily, on each pull request, and on each push to `main`. It runs `pve-overlay verify --no-system` against the newest published Proxmox VE packages from the stable and test repositories. `verify` applies the patches and loads each patched module in a taint-mode Perl process. If a patch fails to apply, update it here against the upstream source for the affected package.

The workflow installs the packages in a container image in GHCR and builds the image from `image/Dockerfile`. The image tag is `<component>-<hash of the Proxmox package index>-<hash of image/Dockerfile>`. The workflow builds a new image when Proxmox publishes a package or when `image/Dockerfile` changes. Otherwise, the workflow pulls the existing image from GHCR.

## Format the Perl scripts

Install Perl::Tidy with `brew install perltidy` on macOS or `cpan Perl::Tidy`
on Linux. This repository uses version `20260826` for formatting. Run `make tidy`
to format the standalone Perl scripts or `make tidy-check` to check their
formatting without changing them.

The [.perltidyrc](.perltidyrc) copies the [Proxmox formatter profile](https://git.proxmox.com/?p=proxmox-perltidy.git;a=blob;f=src/perltidyrc;hb=ba5df00add5bfd70245ae1cbd8eb9d9f55c723f4).
Copyright 2025 Thomas Lamprecht, Proxmox Support Team <support@proxmox.com>.
The [GNU General Public License version 3 or later](LICENSES/GPL-3.0-or-later.txt) applies to the profile.

## Regenerate an overlay patch

Clone the affected upstream repository into a temporary directory. Each package's patches apply in filename order from the [patches directory](patches/). The HTTP server has a single patch.

| Upstream repository | Upstream revision |
| --- | --- |
| [pve-manager](https://github.com/proxmox/pve-manager) | `41a0e2e09b9e6f9da5a19b580a38db2b45ece97b` |
| [pve-access-control](https://github.com/proxmox/pve-access-control) | `dff26b458651b4e1141ff0a41a296d2904b16228` |
| [pve-http-server](https://github.com/proxmox/pve-http-server) | `5c9e4ea773364bdb7ae0e2faec5750fe58129a47` |
| [pve-container](https://github.com/proxmox/pve-container) | `96021ad7dbc4ec8e618de880d59d2a12a9c8c0f1` |
| [qemu-server](https://github.com/proxmox/qemu-server) | `91253ed548ea6bf9fbe8a3b0aa691933e52f8ed7` |

1. Run `git switch --detach <upstream-revision>` in the temporary clone. For access control, restore the module from its separate revision.

   ```sh
   git restore --source=eb08cdfc72371c4d63f371d81f8d25232524e711 --staged --worktree src/PVE/AccessControl.pm
   ```

2. Apply each earlier patch for the package in filename order with `git apply --index <absolute-path>`. Run `git write-tree` and assign the printed tree ID to `base_tree`. Set `patch` to the absolute path of the patch to regenerate and run `git apply --index "$patch"`.

3. Edit the reconstructed source. Format new Perl files with `perltidy --profile=/path/to/proxmox-overlays/.perltidyrc <file>`. For existing Perl files, format a temporary copy and transfer the formatter changes for the edited blocks.

4. Stage the edits and regenerate the patch.

   ```sh
   git add -A
   git diff --cached --check "$base_tree"
   git diff --cached --binary --output="${patch}.new" "$base_tree"
   ```

   Preserve the reduced hunk context where the stable and testing packages differ. Remove the final `/nodes/{node}/certificates` context line from the access control HostNIC `check_path` hunk. End each affected manager `PVE/API2/Nodes.pm` import hunk at `use PVE::API2::Hardware;`. Subtract each removed context line from both hunk line counts.

   In the container guest API patch, remove the leading `PVE::JSONSchema` import from the hunk that adds the `PVE::GuestExecResult` import. In the container BPF delegation patch, remove the leading `},` context line from the hunk that adds `verify_bpf_delegate_list`. For each removed leading line, add one to both starting line numbers and subtract one from both line counts.

5. Reconstruct the same base in a fresh checkout. Apply the regenerated patch and all later patches for that package in order. Review the diff and replace the committed patch. Run `/path/to/proxmox-overlays/pve-overlay verify --no-system` in disposable environments for both current package channels.
