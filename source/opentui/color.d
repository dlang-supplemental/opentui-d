module opentui.color;

/**
 * Packed OpenTUI RGBA (`[4]u16`) matching the Zig core layout.
 *
 * Each component stores an 8-bit channel in the low byte and one byte of a
 * 32-bit metadata word in the high byte (intent + palette slot).
 */

enum ColorIntent : ubyte
{
    rgb = 0,
    indexed = 1,
    default_ = 2,
}

/// Native packed color buffer passed to FFI (`[*]const u16`).
alias PackedRGBA = ushort[4];

private uint packMeta(ColorIntent intent, ubyte slot = 0) pure @safe nothrow @nogc
{
    return cast(uint) slot | (cast(uint) intent << 8);
}

private PackedRGBA packRGBA8(ubyte r, ubyte g, ubyte b, ubyte a, uint meta) pure @safe nothrow @nogc
{
    PackedRGBA out_;
    out_[0] = cast(ushort)(r | ((meta & 0xff) << 8));
    out_[1] = cast(ushort)(g | (((meta >> 8) & 0xff) << 8));
    out_[2] = cast(ushort)(b | (((meta >> 16) & 0xff) << 8));
    out_[3] = cast(ushort)(a | (((meta >> 24) & 0xff) << 8));
    return out_;
}

private ubyte floatToU8(float c) pure @safe nothrow @nogc
{
    import std.math : isFinite;
    if (!isFinite(c))
        return 0;
    if (c < 0)
        c = 0;
    if (c > 1)
        c = 1;
    return cast(ubyte)(c * 255.0f + 0.5f);
}

/// RGBA color with packing helpers for the native core.
struct RGBA
{
    PackedRGBA buffer = packRGBA8(0, 0, 0, 255, packMeta(ColorIntent.rgb));

    /// Channels in 0.0 .. 1.0 (literal RGB intent).
    static RGBA fromFloats(float r, float g, float b, float a = 1.0f) pure @safe nothrow @nogc
    {
        return RGBA(packRGBA8(floatToU8(r), floatToU8(g), floatToU8(b), floatToU8(a), packMeta(ColorIntent.rgb)));
    }

    /// Channels in 0 .. 255 (literal RGB intent).
    static RGBA fromBytes(ubyte r, ubyte g, ubyte b, ubyte a = 255) pure @safe nothrow @nogc
    {
        return RGBA(packRGBA8(r, g, b, a, packMeta(ColorIntent.rgb)));
    }

    /// Parse `#RGB` / `#RRGGBB` / `#RRGGBBAA` (no named CSS colors).
    static RGBA fromHex(string hex) pure @safe
    {
        import std.conv : to;
        import std.string : startsWith, toLower;

        auto s = hex.toLower;
        if (s.startsWith("#"))
            s = s[1 .. $];
        ubyte r, g, b, a = 255;
        if (s.length == 3)
        {
            r = cast(ubyte) to!uint(s[0 .. 1] ~ s[0 .. 1], 16);
            g = cast(ubyte) to!uint(s[1 .. 2] ~ s[1 .. 2], 16);
            b = cast(ubyte) to!uint(s[2 .. 3] ~ s[2 .. 3], 16);
        }
        else if (s.length == 6 || s.length == 8)
        {
            r = cast(ubyte) to!uint(s[0 .. 2], 16);
            g = cast(ubyte) to!uint(s[2 .. 4], 16);
            b = cast(ubyte) to!uint(s[4 .. 6], 16);
            if (s.length == 8)
                a = cast(ubyte) to!uint(s[6 .. 8], 16);
        }
        else
            throw new Exception("invalid hex color: " ~ hex);
        return fromBytes(r, g, b, a);
    }

    const(ushort)* ptr() const return pure @safe nothrow @nogc
    {
        return buffer.ptr;
    }
}

enum RGBA black = RGBA.fromBytes(0, 0, 0);
enum RGBA white = RGBA.fromBytes(255, 255, 255);
enum RGBA red = RGBA.fromBytes(255, 0, 0);
enum RGBA green = RGBA.fromBytes(0, 255, 0);
enum RGBA blue = RGBA.fromBytes(0, 0, 255);
enum RGBA yellow = RGBA.fromBytes(255, 255, 0);
enum RGBA cyan = RGBA.fromBytes(0, 255, 255);
enum RGBA magenta = RGBA.fromBytes(255, 0, 255);
enum RGBA transparent = RGBA.fromBytes(0, 0, 0, 0);
