# jlang-pascal

Object Pascal (Free Pascal / Lazarus) bindings for the **J programming language** (MIT) — a way to embed a J engine (`j.dll`/`libj`) inside Pascal programs, plus a terminal widget for J console UIs.

## What's here

- **`ujlang.pas`** — the core: `TJLang`, a Lazarus `TComponent` wrapping the J shared library via `dynlibs`. `Init(libpath)` / `InitFromEnv` (uses `J_HOME`) load the DLL; exposes J's C API with Pascal types (`TJA` record mirroring J's array header, `JT_*` type codes for all J types incl. sparse and unicode). Event hooks `TJRdEvent`/`TJWrEvent`/`TJWdEvent` for console interaction. Follows the [JFEX interface spec](https://code.jsoftware.com/wiki/Interfaces/JFEX).
- **`ujkvm.pas`** — `TJKVM`, a Lazarus `TCustomControl` implementing a fixed-width text terminal with 24-bit color (ASCII only), built on BGRABitmap. Renders console widgets created with [j-kvm](https://github.com/tangentstorm/j-kvm); reusable for any retro/terminal-style Lazarus UI.
- **`jlang_pascal.lpk`** — the Lazarus package tying both units together (run+designtime, registers the components on the palette).
- **`demo/`** — `jConsoleApp`, a demo console app reimplementing J's `jconsole`: read–eval–print loop over stdin/stdout using `TJLang`.

## Install

Open `jlang_pascal.lpk` in Lazarus and install the package.

## Caveat

Written against the J 9.5-era C API (2023); the `TJA` header layout must match the loaded `j.dll` exactly or it breaks silently. Untested against current J releases.
