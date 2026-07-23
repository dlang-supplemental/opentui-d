# Machine / environment memories

| Fact | Uses |
|------|------|
| OpenTUI native ABI uses `u32` handles (`handles.Handle`), not raw object pointers | 1 |
| Colors are packed `[4]u16` (channel low byte + metadata high byte), not float4 | 1 |
| Official shared libs ship on GitHub Releases as `opentui-native-v*-{platform}.zip` (`opentui.dll` / `libopentui.so` / `libopentui.dylib`) | 1 |
| FFI symbol table lives in `packages/core/src/zig.ts` (`dlopen` rawSymbols); filter with `lib.zig` exports | 1 |
| No official D binding existed as of 2026-07; Go community binding: AnatoleLucet/go-opentui | 1 |
