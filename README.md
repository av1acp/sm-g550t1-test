# SM-G550T1 kernel (on5ltetmo) — GitHub Actions build

Stock Samsung Marshmallow opensource kernel for **SM-G550T1 (Galaxy On5 2016,
T-Mobile)** — `Kernel.tar.gz` from `SM-G550T1_NA_MM_Opensource.zip`, built
automatically on GitHub Actions.

- Kernel: **3.10.9** (`3.10.9-13870322`, stock release string preserved)
- Arch: **arm 32-bit** (Exynos 7570 / universal3475)
- Defconfig: `on5ltetmo_00_defconfig`
- Toolchain: **AOSP arm-eabi-4.8** (`marshmallow-release`), fallback
  `burstlam/arm-eabi-4.9` — matches stock `/proc/version`
  (`gcc version 4.8`), as documented in Samsung's `README_Kernel.txt`
- Output: `arch/arm/boot/zImage-dtb` (= zImage + appended
  `exynos3475-universal3475.dtb`, per `CONFIG_BUILD_ARM_APPENDED_DTB_IMAGE=y`)
- Modules: none — `# CONFIG_MODULES is not set` (stock config)

## Run a build

Actions tab → **Build kernel (SM-G550T1 / on5ltetmo)** → **Run workflow**.

Only manual (`workflow_dispatch`) triggers exist, so builds run only when you
want them. On a **public** repo standard runners are free & unlimited; on a
private repo each run costs ~10-15 of your 2000 included minutes.

Artifact `on5ltetmo-kernel-<run>` contains:

| file              | what it is                                   |
| ----------------- | -------------------------------------------- |
| `zImage-dtb`      | flashable kernel image (zImage + appended DTB) |
| `kernel.config`   | exact `.config` used                         |
| `System.map`      | symbol table                                 |
| `build-info.txt`  | compiler, git rev, sha256 of the image       |
| `SHA256SUMS`      | checksums                                    |

Failed runs upload `build-log-<run>` for debugging.

## What was verified before this was written

- `yylloc` duplicate-definition failure at `scripts/dtc` link reproduced on
  gcc 14, fix (`extern` on the parser copy) confirmed to link clean — required
  because gcc >= 10 defaults to `-fno-common`.
- `KBUILD_IMAGE` resolution to `zImage-dtb`, and the whole DTB chain
  (`DTB_NAMES` from `CONFIG_BUILD_ARM_APPENDED_DTB_IMAGE_NAMES` → `dtbs` rule →
  generic `%.dtb` rule) checked in the actual makefiles.
- AOSP `arm-eabi-4.8` `marshmallow-release` branch cloned (110 MB) and its
  binaries inspected: complete `bin/`, ELF **x86-64** (runs natively on
  ubuntu-24.04 runners; ubuntu-22.04 is being deprecated 2026-09-17 →
  2027-04-17, hence the pinned runner).
- Public-repo Actions = free/unlimited, action versions (`checkout@v7`,
  `upload-artifact@v7`, `cache@v6`) and runner specs (4 vCPU / 16 GB)
  confirmed against live GitHub docs/API.

## Build locally (x86-64 Linux host)

    sudo apt-get install bc flex bison
    ./build.sh

Note: the toolchain binaries are x86-64 — this does **not** run on ARM hosts
(e.g. Raspberry Pi) without emulation.

For a clean rebuild: `make ARCH=arm distclean && ./build.sh`

## Flashing warning

This builds the **on5ltetmo (G550T1)** configuration and its
`exynos3475-universal3475.dtb`. The phone currently connected over ADB in this
workstation is a **SM-G550FY (o5prolte)** — a different board. Do not flash
this image onto G550FY (or any other variant) without confirming the
defconfig/DTB matches that device.
