module opentui.renderer;

import opentui.buffer : Buffer;
import opentui.color : RGBA;
import opentui.exception : OpenTuiException;
import ffi = opentui.ffi;

/// Where renderer output is written when no span-feed is attached.
enum OutputDestination : ubyte
{
    stdout = 0,
    memory = 1,
}

/// Terminal remote-mode hint passed to the native core.
enum RemoteMode : ubyte
{
    auto_ = 0,
    local = 1,
    remote = 2,
}

/// Options for `Renderer.create`.
struct RendererOptions
{
    OutputDestination destination = OutputDestination.stdout;
    RemoteMode remoteMode = RemoteMode.auto_;
}

/**
 * High-level wrapper around OpenTUI's native `CliRenderer`.
 *
 * Component factories (`Box`, `Text`, layout) still live primarily in the
 * TypeScript layer; this wrapper exposes the imperative native renderer /
 * buffer API that other language bindings use.
 */
final class Renderer
{
    private ffi.NativeHandle handle = ffi.invalidHandle;

    private this(ffi.NativeHandle h) pure @safe nothrow
    {
        handle = h;
    }

    /**
     * Create a renderer. Requires a prior `opentui.load()`.
     * Returns a live instance or throws on failure.
     */
    static Renderer create(uint width, uint height, RendererOptions options = RendererOptions.init)
    {
        if (width == 0 || height == 0)
            throw new OpenTuiException("renderer width/height must be non-zero");
        if (!ffi.isLoaded)
            throw new OpenTuiException("OpenTUI native library is not loaded; call opentui.load()");

        auto h = ffi.createRenderer(
            width,
            height,
            cast(ubyte) options.destination,
            cast(ubyte) options.remoteMode,
            null
        );
        if (h == ffi.invalidHandle)
            throw new OpenTuiException("createRenderer failed");
        return new Renderer(h);
    }

    ~this()
    {
        destroy();
    }

    void destroy()
    {
        if (handle != ffi.invalidHandle && ffi.isLoaded)
        {
            ffi.destroyRenderer(handle);
            handle = ffi.invalidHandle;
        }
    }

    @property ffi.NativeHandle nativeHandle() const pure @safe nothrow @nogc
    {
        return handle;
    }

    @property bool valid() const pure @safe nothrow @nogc
    {
        return handle != ffi.invalidHandle;
    }

    void setUseThread(bool enabled)
    {
        ensure();
        ffi.setUseThread(handle, enabled);
    }

    void setClearOnShutdown(bool enabled)
    {
        ensure();
        ffi.setClearOnShutdown(handle, enabled);
    }

    void setBackgroundColor(RGBA color)
    {
        ensure();
        ffi.setBackgroundColor(handle, cast(void*) color.ptr);
    }

    void setRenderOffset(uint offset)
    {
        ensure();
        ffi.setRenderOffset(handle, offset);
    }

    /// Borrow the next draw buffer (owned by the renderer).
    Buffer nextBuffer()
    {
        ensure();
        auto h = ffi.getNextBuffer(handle);
        if (h == ffi.invalidHandle)
            throw new OpenTuiException("getNextBuffer failed");
        return Buffer.borrow(h);
    }

    /// Render the current frame. Returns the native status byte.
    ubyte renderFrame(bool force = false)
    {
        ensure();
        return ffi.render(handle, force);
    }

    void resize(uint width, uint height)
    {
        ensure();
        if (width == 0 || height == 0)
            throw new OpenTuiException("invalid dimensions");
        ffi.resizeRenderer(handle, width, height);
    }

    void clearTerminal()
    {
        ensure();
        ffi.clearTerminal(handle);
    }

    void enableMouse(bool movement = true)
    {
        ensure();
        ffi.enableMouse(handle, movement);
    }

    void disableMouse()
    {
        ensure();
        ffi.disableMouse(handle);
    }

    private void ensure() const
    {
        if (handle == ffi.invalidHandle)
            throw new OpenTuiException("Renderer handle is invalid");
        if (!ffi.isLoaded)
            throw new OpenTuiException("OpenTUI native library is not loaded; call opentui.load()");
    }
}
