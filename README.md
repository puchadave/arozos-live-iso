# ArozOS Alpine Live ISO

Native ArozOS on Alpine Linux, packaged as a bootable live ISO without an Alpine diskless RAM root.

## Key design

- Alpine 3.24 / x86_64 / OpenRC.
- ArozOS is built from `tobychui/arozos` with `CGO_ENABLED=0`.
- `make web` runs during the image build and `dist/web.tar.gz` is extracted directly into `/opt/arozos` **before SquashFS is created**.
- The live root is `images/rootfs.squashfs` mounted read-only from ISO, with only a small tmpfs OverlayFS write layer.
- DHCP uses BusyBox `udhcpc`; NetworkManager is not required for live boot.
- ArozOS listens on port 8080. After DHCP, open `http://<IP>:8080/desktop.html`.

## Build

```sh
docker run --rm --privileged -v "$PWD:/work" -w /work alpine:3.24 \
  sh -lc 'apk add --no-cache bash && bash scripts/build-live-iso.sh'
```

Output: `output/arozos-alpine-live-v0.3.2-x86_64.iso`.

## Package manifests

`requirements/core.txt` is deliberately based on the proven native Alpine installation path. Build-only packages (`go`, `git`, `make`) never enter the live root. Installer and rescue packages are separated into their own manifests.

## Curated APK index / gateway

`apk-repo/build-index.sh` resolves the union of core + installer + rescue packages and all recursive dependencies from Alpine `main`, `community` and tagged `testing`. It emits only `APKINDEX.tar.gz`, `packages.list` and `requirements.txt`; downloaded APK payloads are discarded.

`gateway/` is a small Go reverse proxy. It serves the curated index and streams only package filenames present in `packages.list` from the official Alpine CDN. The gateway therefore stores no permanent Alpine `.apk` mirror while keeping package versions refreshable by regenerating the index.
