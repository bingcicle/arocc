const std = @import("std");
const mem = std.mem;
const builtin = @import("builtin");
const is_windows = builtin.os.tag == .windows;

pub const Color = enum {
    reset,
    red,
    green,
    blue,
    cyan,
    purple,
    yellow,
    white,
};

pub fn fileSupportsColor(file: std.fs.File) bool {
    return file.supportsAnsiEscapeCodes() or (is_windows and file.isTty());
}

pub fn setColor(color: Color, w: anytype) void {
    if (is_windows) {
        const stderr_file = std.io.getStdErr();
        if (!stderr_file.isTty()) return;
        const windows = std.os.windows;
        const S = struct {
            var attrs: windows.WORD = undefined;
            var init_attrs = false;
        };
        if (!S.init_attrs) {
            S.init_attrs = true;
            var info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
            _ = windows.kernel32.GetConsoleScreenBufferInfo(stderr_file.handle, &info);
            S.attrs = info.wAttributes;
            _ = windows.kernel32.SetConsoleOutputCP(65001);
        }

        // need to flush bufferedWriter
        const T = if (@typeInfo(@TypeOf(w.context)) == .Pointer) @TypeOf(w.context.*) else @TypeOf(w.context);
        if (T != void and @hasDecl(T, "flush")) w.context.flush() catch {};

        switch (color) {
            .reset => _ = windows.SetConsoleTextAttribute(stderr_file.handle, S.attrs) catch {},
            .red => _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_RED | windows.FOREGROUND_INTENSITY) catch {},
            .green => _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_GREEN | windows.FOREGROUND_INTENSITY) catch {},
            .blue => _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY) catch {},
            .cyan => _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY) catch {},
            .purple => _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_RED | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY) catch {},
            .yellow => _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_INTENSITY) catch {},
            .white => _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY) catch {},
        }
    } else switch (color) {
        .reset => w.writeAll("\x1b[0m") catch {},
        .red => w.writeAll("\x1b[31;1m") catch {},
        .green => w.writeAll("\x1b[32;1m") catch {},
        .blue => w.writeAll("\x1b[34;1m") catch {},
        .cyan => w.writeAll("\x1b[36;1m") catch {},
        .purple => w.writeAll("\x1b[35;1m") catch {},
        .yellow => w.writeAll("\x1b[93;1m") catch {},
        .white => w.writeAll("\x1b[0m\x1b[1m") catch {},
    }
}

pub fn errorDescription(err: anyerror) []const u8 {
    return switch (err) {
        error.OutOfMemory => "ran out of memory",
        error.FileNotFound => "file not found",
        error.IsDir => "is a directory",
        error.NotDir => "is not a directory",
        error.NotOpenForReading => "file is not open for reading",
        error.NotOpenForWriting => "file is not open for writing",
        error.InvalidUtf8 => "input is not valid UTF-8",
        error.FileBusy => "file is busy",
        error.NameTooLong => "file name is too long",
        error.AccessDenied => "access denied",
        error.FileTooBig => "file is too big",
        error.ProcessFdQuotaExceeded, error.SystemFdQuotaExceeded => "ran out of file descriptors",
        error.SystemResources => "ran out of system resources",
        error.FatalError => "a fatal error occurred",
        error.Unexpected => "an unexpected error occurred",
        else => @errorName(err),
    };
}

fn canExecutePosix(path: []const u8) bool {
    std.os.access(path, std.os.X_OK) catch return false;
    // Todo: ensure path is not a directory
    return true;
}

/// TODO
fn canExecuteWindows(path: []const u8) bool {
    _ = path;
    return true;
}

pub fn canExecute(path: []const u8) bool {
    if (is_windows) {
        return canExecuteWindows(path);
    } else {
        return canExecutePosix(path);
    }
}

pub fn exists(path: []const u8) bool {
    std.os.access(path, std.os.F_OK) catch return false;
    return true;
}

/// TODO
fn findProgramByNameWindows(allocator: std.mem.Allocator, name: []const u8, buf: []u8) ?[]const u8 {
    _ = buf;
    _ = name;
    _ = allocator;
    return null;
}

/// TODO: does WASI need special handling?
fn findProgramByNamePosix(name: []const u8, buf: []u8) ?[]const u8 {
    if (mem.indexOfScalar(u8, name, '/') != null) {
        @memcpy(buf[0..name.len], name);
        return buf[0..name.len];
    }
    const path_env = std.os.getenvZ("PATH") orelse return null;
    var fib = std.heap.FixedBufferAllocator.init(buf);

    var it = mem.tokenizeScalar(u8, path_env, ':');
    while (it.next()) |path_dir| {
        defer fib.reset();
        const full_path = std.fs.path.join(fib.allocator(), &.{ path_dir, name }) catch continue;
        if (canExecute(full_path)) return full_path;
    }

    return null;
}

/// Search for an executable named `name` using platform-specific logic
/// If it's found, write the full path to `buf` and return a slice of it
/// Otherwise retun null
pub fn findProgramByName(allocator: std.mem.Allocator, name: []const u8, buf: []u8) ?[]const u8 {
    std.debug.assert(name.len > 0);
    if (is_windows) {
        return findProgramByNameWindows(allocator, name, buf);
    } else {
        return findProgramByNamePosix(name, buf);
    }
}
