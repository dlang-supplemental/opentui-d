import opentui;

void main()
{
    import std.file : exists;
    import std.path : buildPath;
    import std.stdio : writeln;

    version (Windows)
    {
        auto lib = buildPath("native", "windows-x64", "opentui.dll");
        if (!exists(lib))
            lib = buildPath("..", "native", "windows-x64", "opentui.dll");
    }
    else version (OSX)
    {
        auto lib = buildPath("native", "darwin-arm64", "libopentui.dylib");
        if (!exists(lib))
            lib = buildPath("native", "darwin-x64", "libopentui.dylib");
    }
    else
    {
        auto lib = buildPath("native", "linux-x64", "libopentui.so");
        if (!exists(lib))
            lib = buildPath("native", "linux-arm64", "libopentui.so");
    }

    if (!exists(lib))
    {
        writeln("Native library not found. Run: pwsh tools/fetch_native.ps1");
        return;
    }

    load(lib);
    scope (exit)
        unload();

    auto renderer = Renderer.create(48, 12);
    scope (exit)
        renderer.destroy();

    renderer.setBackgroundColor(black);
    auto buf = renderer.nextBuffer();
    buf.clear(black);
    buf.drawText("Hello from opentui-d!", 2, 2, green);
    buf.drawText("Ctrl+C in a full app loop to exit.", 2, 4, cyan);
    renderer.renderFrame(true);
}
