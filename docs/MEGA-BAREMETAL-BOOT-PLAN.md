# webOwie / ArozOS Bare-Metal Boot Image Plan

Status: implementation baseline for v0.4

## Scope

This repository is the only writable project for the ISO/hardware boot work. It targets physical bare-metal machines. Virtual machines are not a release acceptance target.

## Deliverables

The build must produce small, independently testable images plus one all-in-one image:

1. `arozos-live-<arch>.iso` - immutable ArozOS live system.
2. `arozos-installer-<arch>.iso` - disk installer and storage tooling.
3. `arozos-rescue-<arch>.iso` - rescue and diagnostics.
4. `arozos-pxe-boot-<arch>.iso` - local iPXE bootstrap client.
5. `arozos-pxe-se-<arch>.iso` - PXE Server Edition, able to provide network boot services to other physical machines.
6. `arozos-mega-<arch>.iso` - all-in-one GRUB menu containing the local modes above and a network-boot entry.

The small images are the primary diagnostic units. The mega image is assembled only from components that pass structural tests.

## Architectures

- `x86_64`: Legacy BIOS + UEFI.
- `aarch64`: UEFI-only target. No fake Legacy BIOS support is to be claimed.

Architecture-specific images stay separate so Ventoy/iVentoy can be used to compare boot methods and hardware behavior without hiding architecture differences.

## Shared live-root design

- Alpine Linux base.
- ArozOS compiled before SquashFS creation.
- read-only SquashFS root.
- tmpfs OverlayFS upper/work layer.
- no full root filesystem extraction into RAM at boot.
- OpenRC userspace.
- early hardware discovery and network initialization from initramfs only where the selected mode needs it.

## Boot modes

The mega image exposes:

- Live
- Live debug
- Installer
- Rescue
- Alpine maintenance shell
- PXE/iPXE client boot
- PXE Server Edition
- Local disk / firmware return where supported

Each mode is selected by explicit kernel command-line state. One root image may contain the superset of required userspace packages, but service activation must remain mode-specific.

## PXE client

The PXE client ISO contains a locally built, pinned iPXE binary and does not rely on downloading an executable bootloader at runtime. Network configuration may use DHCP. A remote boot script URL is configurable, but failure must return the operator to an interactive iPXE shell instead of looping forever.

## PXE Server Edition

PXE-SE is a server role, not the PXE client. It will provide a locally controlled boot service using standard components. Initial server responsibilities:

- DHCP proxy mode by default so existing DHCP servers are not silently replaced.
- TFTP only for the small initial bootloader handoff where required.
- iPXE for richer client logic.
- HTTP for kernel/initramfs/image delivery.
- optional NFS root support.
- local image directory and generated iPXE menu.

Destructive DHCP-authoritative mode must never be enabled automatically.

## Hardware-first acceptance

Automated CI may validate scripts, image structure, checksums, El Torito entries and EFI contents. It does not prove bare-metal compatibility.

A release is considered hardware-validated only after recording tests on physical machines, including at least:

- one Legacy BIOS x86_64 machine;
- one UEFI x86_64 machine;
- multiple physical NIC families when available;
- one UEFI aarch64 machine for ARM64 releases.

Each result must record machine/board, firmware mode, NIC, storage controller, selected image/mode and outcome.

## Source and provenance policy

External open-source projects may be studied or incorporated where their licences permit it. Imported code or binaries must have their source project, version/commit and licence recorded. Runtime bootloaders are pinned to explicit versions or commits.

Current upstream references include Alpine Linux, ArozOS, GNU GRUB, iPXE and Ventoy. Ventoy/iVentoy are test/deployment selectors, not hidden dependencies of the generated images.

## Commit policy

Implementation is intentionally granular. Tests/contracts are committed before the corresponding implementation where practical. Independent changes are separate commits so regressions can be bisected without reconstructing a giant mixed commit.

## Initial implementation order

1. freeze and document the v0.3.3 BIOS/UEFI/initramfs baseline;
2. introduce image profiles and mode contract tests;
3. refactor the builder into shared rootfs + per-image assembly;
4. produce Live, Installer and Rescue images;
5. add pinned local iPXE client image;
6. add PXE-SE userspace and configuration;
7. assemble the mega image;
8. add deterministic checksums/manifests;
9. add hardware test record format and release gate;
10. perform physical-machine validation before declaring v0.4 hardware-ready.
