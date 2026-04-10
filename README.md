# filc-bootstrap

**Distro-agnostic bootstrap for Fil-C** — the memory-safe C/C++ compiler.

This repository contains the reusable scripts and logic needed to inject Fil-C into a minimal Linux chroot (including a vanilla Gentoo stage 3).

### Goal

Turn a normal (Yolo-C) base system into a **pizlonated** environment where:
- The Fil-C compiler (`filcc` / `fil++`) and runtime (`libpizlo.so`) are installed.
- A **dual-libc sandwich** is created (Yolo glibc + User glibc compiled with Fil-C).
- New compilations produce memory-safe binaries by default.

### Bootstrap Levels (Fil-C / Pizlix style)

The process is divided into three conceptual phases (adapted for reusability and Gentoo):

- **Pre-LC (Stage 1 equivalent)**  
  Prepare the base environment, install build dependencies, clone Fil-C, and build the Fil-C toolchain + runtime.

- **LC (Stage 2 equivalent — the critical transition)**  
  This is the heart of the bootstrap.  
  - Build **Yolo glibc** (normal unsafe) for the runtime.  
  - "Yoloify" critical binaries (`patchelf`).  
  - Build **User glibc** with Fil-C (memory-safe).  
  - Install the Fil-C compiler and switch the environment so new builds use the safe libc.  

- **Post-LC hand-off**  
  After LC succeeds, control is handed over to the Distro-specific package repository.
  For Gentoo (`pilc-overlay`), it continues the system install for both `@system` and `@world`.

### Purpose

- Provide **reusable, idempotent, and recoverable** bash scripts (with optional Python helpers).
- Support incremental updates to the Fil-C toolchain without always starting from a fresh stage 3.
- Be as distro-agnostic as possible so the same core logic can work on Gentoo, Debian chroots, Alpine, LFS, etc.
- Make checkpoints and recovery easy (snapshots, `.done` files, `--recover-lc`, `--update-filc` flags).

### Default Language Standards (Fil-C)

Fil-C is based on **Clang 20.1.8** and uses modern, strict defaults:

- **C**: `-std=c17` (ISO C17) by default — **not** `gnu17`
- **C++**: `-std=c++20` (ISO C++20) by default — **not** `gnu++20`

**GNU extensions are NOT enabled by default.**  
Many packages will need `-std=gnu17` (C) or `-std=gnu++20` (C++) added via `make.conf` or per-package flags.

### Default Bootstrap Language

- **Primary**: Bash (for maximum portability and alignment with existing Fil-C / Pizlix scripts).
- **Optional helpers**: Python (for complex logic such as emerge parsing, patch management, or structured logging).

The bootstrap itself will eventually be compilable with Fil-C for full memory safety.

### Repository Structure (planned)

```
filc-bootstrap/
├── bootstrap.sh
├── config.sh
├── phases/
│   ├── 01-prepare-base.sh
│   ├── 02-build-filc-toolchain.sh
│   ├── 03-setup-dual-libc.sh      # LC phase (most complex)
│   └── 04-gentoo-bridge.sh
├── utils/
├── patches/
└── docs/
```

See the `phases/` and `utils/` directories for detailed documentation.

---

**Status**: Early planning / initial scripts  
**Related repo**: [filc-gentoo](https://github.com/orsonteodoro/filc-overlay) (Ebuild overlay + Post-LC rebuild)
