#!/usr/bin/env python3
"""Generate OpenTUI D bindings from zig.ts (+ optional lib.zig export filter)."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

FFI_TO_D = {
    "u8": "ubyte",
    "u16": "ushort",
    "u32": "uint",
    "u64": "ulong",
    "i8": "byte",
    "i16": "short",
    "i32": "int",
    "i64": "long",
    "f32": "float",
    "f64": "double",
    "bool": "bool",
    "void": "void",
    "ptr": "void*",
    "cstring": "const(char)*",
    "function": "void*",
}

SKIP = {"symbols"}


def extract_symbol_block(text: str) -> str:
    m = re.search(r"const rawSymbols = dlopen\([^,]+,\s*\{", text)
    if not m:
        raise SystemExit("could not find dlopen symbol table")
    start = m.end()
    depth = 1
    i = start
    while i < len(text) and depth:
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    return text[start : i - 1]


def parse_symbols(block: str) -> list[dict]:
    entry_re = re.compile(
        r"(\w+)\s*:\s*\{\s*args\s*:\s*\[(.*?)\]\s*,\s*returns\s*:\s*"
        r'(?:"([^"]+)"|(function)|(\{))',
        re.S,
    )
    syms = []
    seen = set()
    for em in entry_re.finditer(block):
        name = em.group(1)
        if name in SKIP or name in seen:
            continue
        args_raw = em.group(2)
        ret = em.group(3) or "ptr"
        args = []
        for tok in re.finditer(r'"([^"]+)"|(\bfunction\b)', args_raw):
            args.append(tok.group(1) or "function")
        seen.add(name)
        syms.append({"name": name, "args": args, "returns": ret})
    return syms


def zig_exports(lib_zig: Path) -> set[str]:
    text = lib_zig.read_text(encoding="utf-8")
    return set(re.findall(r"(?:pub\s+)?export\s+fn\s+(\w+)", text))


def d_type(ffi: str) -> str:
    if ffi not in FFI_TO_D:
        raise KeyError(f"unknown FFI type: {ffi!r}")
    return FFI_TO_D[ffi]


def arg_list(args: list[str]) -> str:
    return ", ".join(f"{d_type(a)} arg{i}" for i, a in enumerate(args))


def fn_type(s: dict) -> str:
    return f"{d_type(s['returns'])} function({arg_list(s['args'])}) nothrow @nogc"


def emit_c(syms: list[dict], version: str) -> str:
    lines = [
        "module opentui.c;",
        "",
        "/**",
        " * Auto-generated `extern(C)` bindings for OpenTUI's native Zig core.",
        f" * Target native release: {version}",
        " * Source: packages/core/src/zig.ts (anomalyco/opentui)",
        " * Regenerate: `python tools/gen_bindings.py --zig-ts path/to/zig.ts`",
        " *",
        " * Prefer `opentui.ffi` (dynamic load). This module is for static linking.",
        " */",
        "",
        "extern (C) nothrow @nogc",
        "{",
        "",
        "    /// Opaque object handle used by the native core (see handles.zig).",
        "    alias NativeHandle = uint;",
        "",
        "    enum NativeHandle invalidHandle = 0;",
        "",
    ]
    for s in syms:
        lines.append(f"    {d_type(s['returns'])} {s['name']}({arg_list(s['args'])});")
    lines += ["", "}", ""]
    return "\n".join(lines)


def emit_ffi(syms: list[dict], version: str) -> str:
    lines = [
        "module opentui.ffi;",
        "",
        "/**",
        " * Auto-generated dynamic loader for OpenTUI's native shared library.",
        f" * Target native release: {version}",
        " * Regenerate: `python tools/gen_bindings.py --zig-ts path/to/zig.ts`",
        " */",
        "",
        "import std.exception : enforce;",
        "import std.string : fromStringz, toStringz;",
        "",
        "version (Windows)",
        "{",
        "    import core.sys.windows.winbase : FreeLibrary, GetProcAddress, LoadLibraryA;",
        "    import core.sys.windows.windef : HMODULE;",
        "}",
        "else",
        "{",
        "    import core.sys.posix.dlfcn : RTLD_NOW, dlclose, dlerror, dlopen, dlsym;",
        "}",
        "",
        "alias NativeHandle = uint;",
        "enum NativeHandle invalidHandle = 0;",
        "",
        "private __gshared void* libHandle;",
        "private __gshared bool loaded;",
        "",
    ]
    for s in syms:
        lines.append(f"alias da_{s['name']} = {fn_type(s)};")
    lines.append("")
    for s in syms:
        lines.append(f"__gshared da_{s['name']} {s['name']};")
    lines += [
        "",
        "private void* loadSym(const(char)* name)",
        "{",
        "    version (Windows)",
        "        return cast(void*) GetProcAddress(cast(HMODULE) libHandle, name);",
        "    else",
        "        return dlsym(libHandle, name);",
        "}",
        "",
        "private void bind(alias dest)(string name)",
        "{",
        "    auto p = loadSym(toStringz(name));",
        "    enforce(p !is null, \"OpenTUI symbol missing: \" ~ name);",
        "    dest = cast(typeof(dest)) p;",
        "}",
        "",
        "/// True after a successful `loadLibrary` call.",
        "@property bool isLoaded() nothrow @nogc",
        "{",
        "    return loaded;",
        "}",
        "",
        "/**",
        " * Load `opentui` / `libopentui` from `path`, or from the default name",
        " * when `path` is null (DLL/so/dylib search path).",
        " */",
        "void loadLibrary(string path = null)",
        "{",
        "    if (loaded)",
        "        return;",
        "",
        "    version (Windows)",
        "    {",
        "        auto candidate = path is null ? \"opentui.dll\" : path;",
        "        libHandle = cast(void*) LoadLibraryA(toStringz(candidate));",
        "        enforce(libHandle !is null, \"failed to LoadLibrary: \" ~ candidate);",
        "    }",
        "    else version (OSX)",
        "    {",
        "        auto candidate = path is null ? \"libopentui.dylib\" : path;",
        "        libHandle = dlopen(toStringz(candidate), RTLD_NOW);",
        "        enforce(libHandle !is null, \"failed to dlopen: \" ~ candidate ~ \" (\" ~ fromStringz(dlerror()).idup ~ \")\");",
        "    }",
        "    else",
        "    {",
        "        auto candidate = path is null ? \"libopentui.so\" : path;",
        "        libHandle = dlopen(toStringz(candidate), RTLD_NOW);",
        "        enforce(libHandle !is null, \"failed to dlopen: \" ~ candidate ~ \" (\" ~ fromStringz(dlerror()).idup ~ \")\");",
        "    }",
        "",
    ]
    for s in syms:
        lines.append(f'    bind!{s["name"]}("{s["name"]}");')
    lines += [
        "",
        "    loaded = true;",
        "}",
        "",
        "/// Unload the native library. Safe to call multiple times.",
        "void unloadLibrary()",
        "{",
        "    if (!loaded)",
        "        return;",
        "    version (Windows)",
        "        FreeLibrary(cast(HMODULE) libHandle);",
        "    else",
        "        dlclose(libHandle);",
        "    libHandle = null;",
        "    loaded = false;",
        "}",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    import argparse

    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--zig-ts", required=True, type=Path)
    ap.add_argument("--lib-zig", type=Path, help="Filter to export fn names from lib.zig")
    ap.add_argument("--version", default="unknown")
    ap.add_argument("--out-dir", type=Path, default=Path("source/opentui"))
    ap.add_argument("--json", type=Path, default=Path("tools/ffi-symbols.json"))
    args = ap.parse_args()

    text = args.zig_ts.read_text(encoding="utf-8")
    syms = parse_symbols(extract_symbol_block(text))
    if args.lib_zig:
        allowed = zig_exports(args.lib_zig)
        before = len(syms)
        syms = [s for s in syms if s["name"] in allowed]
        print(f"filtered {before} -> {len(syms)} using lib.zig exports", file=sys.stderr)

    print(f"emitting {len(syms)} symbols", file=sys.stderr)
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(syms, indent=2) + "\n", encoding="utf-8")
    (args.out_dir / "c.d").write_text(emit_c(syms, args.version), encoding="utf-8")
    (args.out_dir / "ffi.d").write_text(emit_ffi(syms, args.version), encoding="utf-8")
    print(f"wrote {args.out_dir / 'c.d'}")
    print(f"wrote {args.out_dir / 'ffi.d'}")
    print(f"wrote {args.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
