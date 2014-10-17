module moyo.mobject;
import std.conv;
alias wstring mstring;
enum ObjectType : byte
{
    Void,Object,Int,Function
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
    mstring String;
    Function Func;
}
//alias typeof(&opAddInt32) operator;//MObject function (ref MObject, ref MObject) operator;
class MObject__vfptr
{
    //__vtbl
    mstring function(ref MObject) toString;
    alias operator = MObject function(ref MObject, ref MObject);
    operator opAdd;
    operator opSub;
    operator opMul;
    operator opDiv;
    operator opMod;
    nativeFunctionType opCall;
    ObjectType type;
    public this(ObjectType type, mstring function(ref MObject) to_s,
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
    public this(mstring function(ref MObject) to_s, nativeFunctionType opCall)
    {
        this.type = ObjectType.Function;
        this.toString = to_s;
        this.opCall = opCall;
    }
    public MObject__vfptr addOpCall(nativeFunctionType nft)
    {
        opCall = nft;
        return this;
    }
}
MObject__vfptr vfptrs[ObjectType.max + 1] = [
    ObjectType.Void: new MObject__vfptr(ObjectType.Void, &toStringTypename!"Void"),
    ObjectType.Object: new MObject__vfptr(ObjectType.Object, &toStringObject, &NoImplFunctionA2),
    ObjectType.Int: new MObject__vfptr(ObjectType.Int, &toStringInt32, &opAddInt32, &opSubInt32, &opMulInt32, &opDivInt32, &opModInt32),
    ObjectType.Function: new MObject__vfptr(ObjectType.Function, &toStringFunction),
];
struct MObject
{
    public @property ObjectType Type(){return type;}
    protected ObjectType type;
    MObjectUnion value;
    public this(Function value)
    {
        this.value.Func = value;
        this.type = ObjectType.Function;
    }
    public this(int value)
    {
        this.value.Int32 = value;
        this.type = ObjectType.Int;
    }
    public mstring toString()
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
    public MObject call(Array!MObject op1)
    {
        return MObject();
    }
}
MObject Void = MObject();
public int getInt32(ref MObject mobject)
{
    return mobject.value.Int32;
}
public mstring toStringTypename(string S)(ref MObject)
{
    return S;
}
public mstring toStringObject(ref MObject mob)
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
public mstring toStringInt32(ref MObject mob)
{
    return to!mstring(mob.value.Int32);
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
import std.container;
abstract class Function
{
    @property mstring name();
    MObject opCall(Array!MObject args);
    mstring toMString();
}
alias Array!MObject argsType;
alias nativeFunctionType = MObject function(argsType);
mstring toStringFunction(ref MObject mob)
{
    return mob.value.Func.toMString();
}
class NativeFunction : Function
{
    public this(nativeFunctionType fu, mstring name = "")
    {
        func = fu;
        _name = name;
    }
    nativeFunctionType func;
    mstring _name;
    override @property mstring name()
    {
        return _name;
    }
    override MObject opCall(Array!MObject args)
    {
        return func(args);
    }
    mstring tom = null;
    override mstring toMString()
    {
        return tom ? tom : tom = ("function(native): " ~ _name);//記録しておく
    }
}
/*
struct Int : MObject
{
    public this(int i)
    {
        
    }
}*/