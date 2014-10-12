module moyo.mobject;
import std.conv;
enum ObjectType : byte
{
    Object,Int,
}
//size 64bit
union MObjectUnion
{
    int Int32;
    uint UInt32;
    float Single;
    double Double;
    byte Byte;
    ubyte UByte;
    wchar Char;
    short Int16;
    ushort UInt16;
    long Int64;
    ulong UInt64;
    wstring String;
}
class MObject__vfptr
{
    wstring function(MObject) toString;
    ObjectType type;
    public this(ObjectType type, wstring function(MObject) to_s)
    {
        this.type = type;
        this.toString = to_s;
    }
}
MObject__vfptr vfptrs[ObjectType.max + 1] = [
    ObjectType.Object: new MObject__vfptr(ObjectType.Object, &toStringObject),
    ObjectType.Int: new MObject__vfptr(ObjectType.Int, &toStringInt32)
];
struct MObject
{
    public @property ObjectType Type(){return type;}
    protected ObjectType type;
    MObjectUnion value;
    public this(int value)
    {
        this.value.Int32 = value;
        type = ObjectType.Int;
    }
    public wstring toString()
    {
        return vfptrs[type].toString(this);
    }
}
public int getInt32(MObject mobject)
{
    return mobject.value.Int32;
}
public wstring toStringObject(MObject mob)
{
    return "Object";
}
public wstring toStringInt32(MObject mob)
{
    return to!wstring(mob.value.Int32);
}
/*
struct Int : MObject
{
    public this(int i)
    {
        
    }
}*/