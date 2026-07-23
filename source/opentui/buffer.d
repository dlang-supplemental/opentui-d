module opentui.buffer;

import opentui.color : RGBA, transparent;
import opentui.exception : OpenTuiException;
import ffi = opentui.ffi;

/**
 * Frame buffer borrowed from a `Renderer` (not owned) or created independently.
 */
final class Buffer
{
    private ffi.NativeHandle handle = ffi.invalidHandle;
    private bool owned;

    private this(ffi.NativeHandle h, bool owned_) pure @safe nothrow
    {
        handle = h;
        owned = owned_;
    }

    /// Create an independent optimized buffer.
    static Buffer create(uint width, uint height, bool respectAlpha = false, ubyte widthMethod = 0, string id = null)
    {
        enforceLoaded();
        auto h = ffi.createOptimizedBuffer(
            width,
            height,
            respectAlpha,
            widthMethod,
            id.length ? cast(void*) id.ptr : null,
            cast(uint) id.length
        );
        if (h == ffi.invalidHandle)
            throw new OpenTuiException("createOptimizedBuffer failed");
        return new Buffer(h, true);
    }

    package static Buffer borrow(ffi.NativeHandle h) pure @safe nothrow
    {
        return new Buffer(h, false);
    }

    ~this()
    {
        destroy();
    }

    void destroy()
    {
        if (owned && handle != ffi.invalidHandle && ffi.isLoaded)
        {
            ffi.destroyOptimizedBuffer(handle);
            handle = ffi.invalidHandle;
            owned = false;
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

    void clear(RGBA color)
    {
        ensure();
        ffi.bufferClear(handle, cast(void*) color.ptr);
    }

    void drawText(string text, uint x, uint y, RGBA fg, RGBA bg = transparent, uint attributes = 0)
    {
        ensure();
        ffi.bufferDrawText(
            handle,
            cast(void*) text.ptr,
            cast(uint) text.length,
            x,
            y,
            cast(void*) fg.ptr,
            cast(void*) bg.ptr,
            attributes
        );
    }

    void fillRect(uint x, uint y, uint width, uint height, RGBA bg)
    {
        ensure();
        ffi.bufferFillRect(handle, x, y, width, height, cast(void*) bg.ptr);
    }

    void resize(uint width, uint height)
    {
        ensure();
        ffi.bufferResize(handle, width, height);
    }

    private void ensure() const
    {
        if (handle == ffi.invalidHandle)
            throw new OpenTuiException("Buffer handle is invalid");
        enforceLoaded();
    }

    private static void enforceLoaded()
    {
        if (!ffi.isLoaded)
            throw new OpenTuiException("OpenTUI native library is not loaded; call opentui.load()");
    }
}
