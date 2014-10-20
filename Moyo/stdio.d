module moyo.stdio;

version(Windows)
{
    import std.windows.charset;
    import std.conv;
    void writelnShiftJIS(T...)(T args)
    {
        foreach(ref a; args)
        {
            static if(is(typeof(a) : const(char)[]) )
            {
                a = to!string(toMBSz(cast(const(char)[])a));   
            }
        }
        std.stdio.stdout.writeln(args);
    }
    void writelnShiftJISFile(T...)(std.file.File file, T args)
    {
        foreach(ref a; args)
        {
            static if(is(typeof(a) : const(char)[]) )
            {
                a = to!string(toMBSz(cast(const(char)[])a));   
            }
        }
        file.writeln(args);
    }
    void writeShiftJIS(T...)(T args)
    {
        foreach(ref a; args)
        {
            static if(is(typeof(a) : const(char)[]) )
            {
                a = to!string(toMBSz(cast(const(char)[])a));   
            }
        }
        std.stdio.stdout.write(args);
    }
    void writeShiftJISFile(T...)(std.file.File file, T args)
    {
        foreach(ref a; args)
        {
            static if(is(typeof(a) : const(char)[]) )
            {
                a = to!string(toMBSz(cast(const(char)[])a));   
            }
        }
        file.write(args);
    }
    void writefShiftJIS(T...)(T args)
    {
        foreach(ref a; args)
        {
            static if(is(typeof(a) : const(char)[]) )
            {
                a = to!string(toMBSz(cast(const(char)[])a));   
            }
        }
        std.stdio.stdout.writef(args);
    }
    void writefShiftJISFile(T...)(std.file.File file, T args)
    {
        foreach(ref a; args)
        {
            static if(is(typeof(a) : const(char)[]) )
            {
                a = to!string(toMBSz(cast(const(char)[])a));   
            }
        }
        file.writef(args);
    }
    void writeflnShiftJIS(T...)(T args)
    {
        foreach(ref a; args)
        {
            static if(is(typeof(a) : const(char)[]) )
            {
                a = to!string(toMBSz(cast(const(char)[])a));   
            }
        }
        std.stdio.stdout.writefln(args);
    }
    void writeflnShiftJISFile(T...)(std.file.File file, T args)
    {
        foreach(ref a; args)
        {
            static if(is(typeof(a) : const(char)[]) )
            {
                a = to!string(toMBSz(cast(const(char)[])a));   
            }
        }
        file.writefln(args);
    }
    alias readln = std.stdio.readln;
    alias writeln = writelnShiftJIS;
    alias write = writeShiftJIS;
    alias writef = writefShiftJIS;
    alias writefln = writeflnShiftJIS;
    alias stdout = std.stdio.stdout;
    class stderr
    {
        static void writeln(T...)(T args)
        {
            std.stdio.stderr.writelnShiftJISFile(args);
        }
        static void write(T...)(T args)
        {
            std.stdio.stderr.writeShiftJISFile(args);
        }
        static void writef(T...)(T args)
        {
            std.stdio.stderr.writefShiftJISFile(args);
        }
        static void writefln(T...)(T args)
        {
            std.stdio.stderr.writeflnShiftJISFile(args);
        }
    }
    
}