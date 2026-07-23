module opentui;

/**
 * D bindings for https://github.com/anomalyco/opentui[OpenTUI]'s native Zig core.
 *
 * OpenTUI exposes a C ABI. This package dynamically loads the platform shared
 * library (`opentui.dll` / `libopentui.so` / `libopentui.dylib`) and wraps the
 * imperative renderer / buffer surface in idiomatic D types.
 *
 * Declarative components (`Box`, `Text`, React/Solid reconcilers) remain in the
 * TypeScript packages; use those when you need the full component tree.
 */

public import opentui.buffer;
public import opentui.color;
public import opentui.exception;
public import opentui.ffi : NativeHandle, invalidHandle, isLoaded, loadLibrary, unloadLibrary;
public import opentui.renderer;

/// Load the native library from an explicit path or the default soname.
void load(string libraryPath = null)
{
    loadLibrary(libraryPath);
}

/// Unload the native library.
void unload()
{
    unloadLibrary();
}

unittest
{
    import std.file : exists, getcwd;
    import std.path : buildPath;

    // Prefer a fetched native binary when present; otherwise skip.
    version (Windows)
        auto candidates = [
            buildPath(getcwd(), "native", "windows-x64", "opentui.dll"),
            buildPath(getcwd(), "native", "opentui.dll"),
        ];
    else version (OSX)
        auto candidates = [
            buildPath(getcwd(), "native", "darwin-arm64", "libopentui.dylib"),
            buildPath(getcwd(), "native", "darwin-x64", "libopentui.dylib"),
        ];
    else
        auto candidates = [
            buildPath(getcwd(), "native", "linux-x64", "libopentui.so"),
            buildPath(getcwd(), "native", "linux-arm64", "libopentui.so"),
        ];

    string lib;
    foreach (c; candidates)
    {
        if (exists(c))
        {
            lib = c;
            break;
        }
    }
    if (lib.length == 0)
        return;

    load(lib);
    scope (exit)
        unload();

    auto r = Renderer.create(40, 12, RendererOptions(OutputDestination.memory));
    scope (exit)
        r.destroy();

    auto buf = r.nextBuffer();
    buf.clear(black);
    buf.drawText("Hello, OpenTUI from D!", 1, 1, green);
    assert(r.renderFrame(true) >= 0);
}
