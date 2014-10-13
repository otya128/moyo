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
    bool Boolean;
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
//alias typeof(&opAddInt32) operator;//MObject function (ref MObject, ref MObject) operator;
class MObject__vfptr
{
    //__vtbl
    wstring function(ref MObject) toString;
    alias operator = MObject function(ref MObject, ref MObject);
    operator opAdd;
    operator opSub;
    operator opMul;
    operator opDiv;
    operator opMod;
    ObjectType type;
    public this(ObjectType type, wstring function(ref MObject) to_s,
                operator opAdd = &NoImplFunctionA2,
                operator opSub = &NoImplFunctionA2,
                operator opMul = &NoImplFunctionA2,
                operator opDiv = &NoImplFunctionA2,
                operator opMod = &NoImplFunctionA2)
    {
        this.type = type;
        this.toString = to_s;
        this.opAdd = opAdd;
        this.opSub = opSub;
        this.opMul = opMul;
        this.opDiv = opDiv;
        this.opMod = opMod;
    }
}
MObject__vfptr vfptrs[ObjectType.max + 1] = [
    ObjectType.Object: new MObject__vfptr(ObjectType.Object, &toStringObject, &NoImplFunctionA2),
    ObjectType.Int: new MObject__vfptr(ObjectType.Int, &toStringInt32, &opAddInt32, &opSubInt32, &opMulInt32, &opDivInt32, &opModInt32)
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
    public MObject opAdd(ref MObject op1)
    {
        return vfptrs[type].opAdd(this,op1);
    }
    public MObject opSub(ref MObject op1)
    {
        return vfptrs[type].opSub(this,op1);
    }
    public MObject opMul(ref MObject op1)
    {
        return vfptrs[type].opMul(this,op1);
    }
    public MObject opDiv(ref MObject op1)
    {
        return vfptrs[type].opDiv(this,op1);
    }
    public MObject opMod(ref MObject op1)
    {
        return vfptrs[type].opMod(this,op1);
    }
}
public int getInt32(ref MObject mobject)
{
    return mobject.value.Int32;
}
public wstring toStringObject(ref MObject mob)
{
    return "Object";
}/*
public MObject opCmpObject(MObject op1, MObject op2)
{
    throw 0;
}*/

public MObject NoImplFunctionA2(ref MObject op1, ref MObject op2)
{
    throw new Exception("NoImpl");
}
public wstring toStringInt32(ref MObject mob)
{
    return to!wstring(mob.value.Int32);
}

//継承できないからvfptr 多分他にいい方法ありそう
public MObject opAddInt32(ref MObject op1, ref MObject op2)
{
    return MObject(op1.value.Int32 + op2.value.Int32);
}
public MObject opSubInt32(ref MObject op1, ref MObject op2)
{
    return MObject(op1.value.Int32 - op2.value.Int32);
}
public MObject opMulInt32(ref MObject op1, ref MObject op2)
{
    return MObject(op1.value.Int32 * op2.value.Int32);
}
public MObject opDivInt32(ref MObject op1, ref MObject op2)
{
    return MObject(op1.value.Int32 / op2.value.Int32);
}
public MObject opModInt32(ref MObject op1, ref MObject op2)
{
    return MObject(op1.value.Int32 % op2.value.Int32);
}
/*
struct Int : MObject
{
    public this(int i)
    {
        
    }
}*/