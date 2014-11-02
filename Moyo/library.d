module moyo.library;
import moyo.mobject;
import std.container;
import std.stdio;
MObject printFunc = MObject(new NativeFunction(&print, "print"));
MObject print(ArgsType args)
{
    foreach(ref MObject i; args)
    {
        write(i);
    }
    stdout.flush();
    return Void;
}

MObject printlnFunc = MObject(new NativeFunction(&println, "println"));
MObject println(ArgsType args)
{
    foreach(ref MObject i; args)
    {
        write(i);
    }
    writeln();
    return Void;
}
