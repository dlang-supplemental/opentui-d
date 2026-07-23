module opentui.exception;

/// Thrown when a native OpenTUI call fails or a handle is invalid.
class OpenTuiException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @safe
    {
        super(msg, file, line, next);
    }
}
