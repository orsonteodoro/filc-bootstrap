# filc-bootstrap

**Distro-agnostic bootstrap for Fil-C** — memory-safe C/C++ compiler.

This repository provides reusable scripts to inject Fil-C into a clean environment.

### Important Safety Warning

> **⚠️ This bootstrap is experimental and potentially destructive.**

Fil-C is still in active research/development. The LC phase (dual-libc transition) modifies critical system binaries and libraries using `patchelf`.  
A failed or interrupted LC phase can leave the chroot in a broken state.

**Strongly Recommended:**
- Always run this bootstrap inside a **virtual machine** (KVM, VirtualBox, VMware, QEMU, etc.) for the first several attempts.
- Take **snapshots** of the VM before starting Phase 03 (LC transition).
- Never run this directly on your main/host system.

### Features

- Supports **clean Gentoo stage 3** (recommended for real builds)
- Supports **fast test mode** with Debian or Alpine chroots (ideal for script validation)
- Modular phases with checkpoints and recovery support
- Automatic DNS handling and safety snapshots

### Fil-C Backstory

Fil-C is a personal project by **Filip Pizlo** (senior director of language engineering at Epic Games, previously worked on JavaScriptCore and WebKit). 

Frustrated with the endless stream of memory safety vulnerabilities in large C/C++ codebases, Pizlo created Fil-C with the core philosophy: **"Garbage In, Memory Safety Out"** — take mostly unmodified existing C/C++ code, compile it with Fil-C, and get strong memory safety automatically.

It combines **invisible capabilities** (InvisiCaps) with a high-performance concurrent garbage collector. The project also includes **Pizlix**, a memory-safe Linux distribution built on top of it.

### Software Build Requirements

**Required:**
- A C/C++ compiler supporting **C++17** (Clang recommended)
- `git`
- `cmake` and `ninja`
- `patchelf`
- `wget` or `curl`
- Basic build tools (`build-base` / `build-essential`)

**Recommended:**
- Clang + LLVM development headers
- `libxml2-dev`
- `libcurl4-openssl-dev` (or equivalent)
- `pkg-config`

### VM Build Requirements

These define what the VM guest settings.

**Realistic hardware recommendations:**

- **RAM**: 
  - **Minimum**: 8 GiB
  - **Recommended**: 8–16 GiB (much more comfortable)
  - **Ideal**: 16+ GiB for full Gentoo rebuilds

- **Disk space**: Minimum 40 GB (60+ GB recommended)
- **CPU cores**: 4+ cores (6–8 ideal)

**Note:**
- Phase 02 (building Fil-C toolchain) is the most memory-intensive step.
- The total memory should be 16 GiB with swapfile inside the virtual machine.

### Important Warning: Experimental Status

> **⚠️ Fil-C is still highly experimental (as of 2026)**

- **Code quality**: Large portions of the Fil-C codebase, build system, and libc patches are research-grade and evolve quickly. Expect rough edges, incomplete documentation, and occasional breaking changes.
- **Adoption**: Very low. Primarily used by enthusiasts and researchers. It has **not** been widely tested in production.
- **Compatibility**: While the goal is high compatibility, many real-world packages still require patches.

**Use this bootstrap at your own risk.** Excellent for learning and experimentation, but **not recommended for production systems** yet.

### Disadvantages

- **Significant performance overhead**: Typically 1.5× – 4× slower than normal Clang/GCC, with 20–80% higher memory usage.
- **Sanitizers disabled**: Traditional sanitizers (ASan, UBSan, TSan, etc.) are usually disabled or incompatible because Fil-C provides its own always-on memory safety. This can affect CI testing workflows that rely on sanitizers.
- **Rebuild everything**: You must rebuild almost the entire userland — prebuilt binaries from normal distros will not work.
- **Experimental nature**: Code quality is research-grade. Expect rough edges, missing documentation, and occasional breakage.
- **Limited ecosystem**: Very low adoption. Package support and community help are minimal.

### Compatibility of Fil-C Built Packages

Fil-C produces **ABI-incompatible** binaries due to its dual-libc architecture and runtime requirements:

- **Fil-C compiled packages** cannot directly use prebuilt binaries from existing distributions (Ubuntu, Debian, Fedora, Arch, Gentoo, etc.).
- You must rebuild **almost the entire userland** with Fil-C (this is what the LC + Post-LC phases do).
- Some libraries and binaries may need patches or special build flags.
- **Dynamic linking** to normal (Yolo-C) libraries is limited and often requires the "yoloify" step or wrapper mechanisms.
- **Prebuilt binaries** from mainstream distros generally **will not run** (or will run unsafely) on a fully pizlonated Fil-C system.

In short: Once you go full Fil-C, you are mostly on your own for the package ecosystem.

### Estimated Impacts

| Aspect                  | Estimated Impact                                      | Notes |
|-------------------------|-------------------------------------------------------|-------|
| **Performance**         | **1.5× – 4× slower** (typical)<br>Some code closer to 1.2× | Due to bounds checking, garbage collection, and runtime metadata. Heavy pointer-heavy code suffers more. |
| **Memory Usage**        | **20% – 80% higher**                                  | Garbage collector + capability metadata overhead. |
| **Security**            | **Very high improvement**                             | Catches spatial + temporal memory safety bugs at runtime with deterministic panics instead of silent exploits. |
| **Binary Size**         | **10% – 50% larger**                                  | Extra runtime metadata and checks. |
| **Build Time**          | **2× – 5× longer**                                    | Especially during the initial full rebuild. |

**Security Benefit**: Fil-C eliminates entire classes of memory corruption vulnerabilities (buffer overflows, use-after-free, etc.) that are responsible for the majority of high-severity CVEs in C/C++ software.

### Fil-C vs CHERI

| Aspect                  | Fil-C                                      | CHERI                                          |
|-------------------------|--------------------------------------------|------------------------------------------------|
| **Implementation**      | Pure software (stock x86_64)               | Hardware capabilities (new CPU required)       |
| **Pointer size**        | Unchanged (64-bit)                         | Wider (≥128-bit capabilities)                  |
| **Compatibility**       | Very high                                  | Good, but often requires changes               |
| **Temporal safety**     | Strong (precise concurrent GC)             | Weaker (depends on revocation)                 |
| **Deployment**          | Works today on existing hardware           | Requires new hardware or emulation             |
| **Performance overhead**| Moderate to high (1.5–4×)                  | Very low (~2–5%)                               |

### Quick Start

*** Fast testing (recommended first): ***
```bash
./bootstrap.sh --test          # Uses Debian by default
# or
./bootstrap.sh --test-alpine
```

#### Real Gentoo build:

```bash
./bootstrap.sh --clean-slate
```

#### Other useful flags:--fresh — Ignore checkpoints and start over
* --update-filc — Only rebuild Fil-C toolchain
* --recover-lc — Recover only the LC phase

#### Bootstrap Phases
- Phase 00: Create clean chroot (Gentoo stage 3 / Debian / Alpine)
- Phase 01: Prepare base environment + dependencies
- Phase 02: Build Fil-C toolchain (build_all_fast_glibc.sh)
- Phase 03: Dual-libc LC transition (yolo + user glibc)
- Phase 03.5: Hello World test (critical safety check)
- Phase 04: Gentoo bridge + hand-off to filc-overlay (or your distro's main package repo/overlay)

### Default Language Standards (Fil-C)

* C: -std=c17 (ISO C17) — GNU extensions not enabled by default
* C++: -std=c++20 (ISO C++20) — GNU extensions not enabled by default

You will typically need -std=gnu17 and -std=gnu++20 in make.conf for Gentoo packages.

### Repository Structure

```
filc-bootstrap/
├── bootstrap.sh
├── config.sh
├── phases/
│   ├── 00-setup-clean-slate.sh
│   ├── 01-prepare-base.sh
│   ├── 02-build-filc-toolchain.sh
│   ├── 03-setup-dual-libc.sh
│   ├── 03.5-test-hello-world.sh
│   └── 04-gentoo-bridge.sh
├── utils/
├── patches/
└── logs/
```

---

* Related repository: [filc-overlay](https://github.com/orsonteodoro/filc-overlay) — Gentoo ebuilds and Post-LC integration.
* Status: In active development, testing and development phase, pre-alpha quality, NOT FOR PRODUCTION

---
