# Agent notes — opentui-d

Project facts for agents. Workstation/env facts live only in `$CODE_ROOT/MEMORIES.md`.

- OpenTUI native ABI uses `u32` handles (`handles.Handle`), not raw object pointers
- Colors are packed `[4]u16` (channel low byte + metadata high byte), not float4
- Official shared libs ship on GitHub Releases as `opentui-native-v*-{platform}.zip` (`opentui.dll` / `libopentui.so` / `libopentui.dylib`)
- FFI symbol table lives in `packages/core/src/zig.ts` (`dlopen` rawSymbols); filter with `lib.zig` exports
- No official D binding existed as of 2026-07; Go community binding: AnatoleLucet/go-opentui
