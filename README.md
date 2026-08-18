# ArozOS Alpine Live ISO

A custom Alpine Linux live distribution for [ArozOS](https://github.com/tobychui/arozos).

The design deliberately avoids Alpine diskless `/` in tmpfs. A complete Alpine + ArozOS root filesystem is built once, compressed as SquashFS, mounted read-only from the ISO and combined with a small writable overlay. ArozOS `web/` and `system/` are extracted during the image build and are already present in the root filesystem before boot.

Target: Alpine 3.24, x86_64, ArozOS upstream, OpenRC.
