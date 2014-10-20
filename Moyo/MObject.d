module moyo.mobject;
import std.conv;
import moyo.interpreter;
alias wstring mstring;
enum ObjectType : byte
{
    Void,
    Object,
    Int,
    Boolean,
    String,
    Function
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
    operator opEquals;
    operator opNotEquals;
    operator opLess;
    operator opGreater;
    operator opLessOrEqual;
    operator opGreaterOrEqual;
    bool function(ref MObject) opBool;
    MObject function(ref MObject op1, ArgsType args, Interpreter parent) opCall;
    ObjectType type;
    public this(ObjectType type, mstring function(ref MObject) to_s,
                operator opAdd = &NoImplFunctionA2,
                operator opSub = &NoImplFunctionA2,
                operator opMul = &NoImplFunctionA2,
                operator opDiv = &NoImplFunctionA2,
                operator opMod = &NoImplFunctionA2,
                operator opEquals = &NoImplFunctionA2,
                operator opNotEquals = &NoImplFunctionA2,
                operator opLess = &NoImplFunctionA2,
                operator opGreater = &NoImplFunctionA2,
                operator opLessOrEqual = &NoImplFunctionA2,
                operator opGreaterOrEqual = &NoImplFunctionA2)
    {
        this.type = type;
        this.toString = to_s;
        this.opAdd = opAdd;
        this.opSub = opSub;
        this.opMul = opMul;
        this.opDiv = opDiv;
        this.opMod = opMod;
        this.opEquals = opEquals;
        this.opNotEquals = opNotEquals;
        this.opLess = opLess;
        this.opGreater = opGreater;
        this.opLessOrEqual = opLessOrEqual;
        this.opGreaterOrEqual = opGreaterOrEqual;
    }
    
    public this(mstring function(ref MObject) to_s, MObject function(ref MObject op1, ArgsType args, Interpreter parent) opCall)
    {
        this.type = ObjectType.Function;
        this.toString = to_s;
        this.opCall = opCall;
    }
    public static addOpBool(MObject__vfptr that, bool function(ref MObject) opBool)
    {
        that.opBool = opBool;
        return that;
    }
    public static addOpEquals(MObject__vfptr that, operator opEquals)
    {
        that.opEquals = opEquals;
        return that;
    }
}
MObject__vfptr vfptrs[ObjectType.max + 1] = [
    ObjectType.Void: new MObject__vfptr(ObjectType.Void, &toStringTypename!"Void"),
    ObjectType.Object: new MObject__vfptr(ObjectType.Object, &toStringObject, &NoImplFunctionA2),
    ObjectType.Int: new MObject__vfptr(ObjectType.Int, &toStringInt32, &opAddInt32, &opSubInt32, &opMulInt32, &opDivInt32, &opModInt32,
                                       (ref MObject op1, ref MObject op2)=>
                                       MObject(op1.value.Int32 == op2.value.Int32),
                                       &opNotEqualInt32, &opLessInt32, &opGreaterInt32, &opLessOrEqualInt32, &opGreaterOrEqualInt32),
    ObjectType.Boolean: MObject__vfptr.addOpEquals(
                                                MObject__vfptr.addOpBool(
                                                                         new MObject__vfptr(ObjectType.Boolean, &toStringBoolean), &opBoolBoolean),
                                                (ref MObject op1, ref MObject op2)=>MObject(op1.value.Boolean == op2.value.Boolean)
                                                ),
    ObjectType.String: MObject__vfptr.addOpEquals(
                                               new MObject__vfptr(ObjectType.String, &toStringString, &opAddString),
                                               (ref MObject op1, ref MObject op2)=>MObject(op1.value.String == op2.value.String)
                                               ),
    ObjectType.Function: new MObject__vfptr(&toStringFunction, &Function.opCallFunction),
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
    public this(bool value)
    {
        this.value.Boolean = value;
        this.type = ObjectType.Boolean;
    }
    public this(mstring value)
    {
        this.value.String = value;
        this.type = ObjectType.String;
    }
    public mstring toString()
    {
        return vfptrs[type].toString(this);
    }
    public bool opBool()
    {
        return vfptrs[type].opBool(this);
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
    //上書きしたらマズイ系
    public MObject opEqual(ref MObject op1)
    {
        return vfptrs[type].opEquals(this,op1);
    }
    public MObject call(ArgsType args, Interpreter parent)
    {
        return vfptrs[type].opCall(this, args, parent);
    }
    public MObject opNotEqual(ref MObject op1)
    {
        return vfptrs[type].opNotEquals(this, op1);
    }
    public MObject opLess(ref MObject op1)
    {
        return vfptrs[type].opLess(this, op1);
    }
    public MObject opGreater(ref MObject op1)
    {
        return vfptrs[type].opGreater(this, op1);
    }
    public MObject opLessOrEqual(ref MObject op1)
    {
        return vfptrs[type].opLessOrEqual(this, op1);
    }
    public MObject opGreaterOrEqual(ref MObject op1)
    {
        return vfptrs[type].opGreaterOrEqual(this, op1);
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
public MObject opNotEqualInt32(ref MObject op1, ref MObject op2)
{
    return MObject(op1.value.Int32 != op2.value.Int32);
}
public MObject opLessInt32(ref MObject op1, ref MObject op2)
{
    return MObject(op1.value.Int32 < op2.value.Int32);
}
public MObject opGreaterInt32(ref MObject op1, ref MObject op2)
{
    return MObject(op1.value.Int32 > op2.value.Int32);
}
public MObject opLessOrEqualInt32(ref MObject op1, ref MObject op2)
{
    return MObject(op1.value.Int32 <= op2.value.Int32);
}
public MObject opGreaterOrEqualInt32(ref MObject op1, ref MObject op2)
{
    return MObject(op1.value.Int32 >= op2.value.Int32);
}
mstring toStringBoolean(ref MObject that)
{
    return that.value.Boolean ? "true" : "false";
}
bool opBoolBoolean(ref MObject that)
{
    return that.value.Boolean;
}
mstring toStringString(ref MObject mob)
{
    return mob.value.String;
}
MObject opAddString(ref MObject op1, ref MObject op2)
{
    return MObject(op1.value.String ~ op2.toString());
}
public MObject opEqualString(ref MObject op1, ref MObject op2)
{
    return MObject(op1.value.String != op2.value.String);
}
public MObject opNotEqualString(ref MObject op1, ref MObject op2)
{
    return MObject(op1.value.String != op2.value.String);
}
import std.container;
abstract class Function
{
    @property mstring name();
    MObject opCall(ArgsType args, Interpreter parent);
    mstring toMString();
    static MObject opCallFunction(ref MObject op1, ArgsType args, Interpreter parent)
    {
        return op1.value.Func(args, parent);
    }
}
alias Array!MObject ArgsType;
alias nativeFunctionType = MObject function(ArgsType);
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
    override MObject opCall(ArgsType args, Interpreter parent)
    {
        return func(args);
    }
    mstring tom = null;
    override mstring toMString()
    {
        return tom ? tom : tom = ("function(native): " ~ _name);//記録しておく
    }
}
class MFunction : Function
{
    import moyo.tree;
    DefineFunction tree;
    this(DefineFunction df)
    {
        this.tree = df;
    }
    @property override mstring name()
    {
        return tree.name;
    }
    mstring tom = null;
    override mstring toMString()
    {
        return tom ? tom : tom = ("function: " ~ tree.name);//記録しておく
    }
    override MObject opCall(ArgsType args, Interpreter parent)
    {
        auto intp = new Interpreter(parent.variable.global);
        MObject ret;
        if(args.length != tree.args.length)
        {
            throw new RuntimeException("argument: " ~ toMString);
        }
        for(int i = 0;i < args.length;i++)
        {
            intp.variable.define(tree.args[i].name, args[i]);
        }
        intp.runStatement(this.tree.statement, ret);
        return ret;
    }
}
template GenerateTypeOperator(const char[] op)
{
    const char[] GenerateTypeOperator = "public ValueType op" ~ op ~ "(ValueType op)
        {
        switch(type)
        {
        case ObjectType.Int:
        switch(op.type)
        {
        case ObjectType.Int:
        return this;
        default:
        return errorType;
        }
        default:
        return errorType;
        }
        }";
}
template GenerateBooleanOperator(const char[] op)
{
    const char[] GenerateBooleanOperator = "public ValueType op" ~ op ~ "(ValueType op)
        {
        switch(type)
        {
        case ObjectType.Int:
        switch(op.type)
        {
        case ObjectType.Int:
        return ValueType(ObjectType.Boolean);
        default:
        return errorType;
        }
        default:
        return errorType;
        }
        }";
}
///計算した結果の型を返します。
struct ValueType
{
    string toString()
    {
        return type.to!string;
    }
    static const ValueType errorType = ValueType();
    public this(ObjectType ot)
    {
        type = ot;
    }
    ObjectType type;
    
    public this(ObjectType ot, ObjectType t)
    {
        type = ot;
        retType = t;
    }
    ObjectType retType;
    public ValueType opAdd(ValueType op)
    {
        switch(type)
        {
            case ObjectType.Int:
                switch(op.type)
                {
                    case ObjectType.Int:
                        return this;
                    default:
                        return errorType;
                }
            case ObjectType.String:
                return this;
            default:
                return errorType;
        }
    }
    mixin(GenerateTypeOperator!"Sub");
    mixin(GenerateTypeOperator!"Mul");
    mixin(GenerateTypeOperator!"Div");
    mixin(GenerateTypeOperator!"Mod");

    mixin(GenerateBooleanOperator!"Less");
    mixin(GenerateBooleanOperator!"Greater");
    mixin(GenerateBooleanOperator!"LessOrEqual");
    mixin(GenerateBooleanOperator!"GreaterOrEqual");
    public ValueType opEqual(ValueType op)
    {
        switch(type)
        {
            default:
                return ValueType(ObjectType.Boolean);
        }
    }
    public ValueType opNotEqual(ValueType op)
    {
        switch(type)
        {
            default:
                return ValueType(ObjectType.Boolean);
        }
    }
    //クラスなどを実装した場合ここに記述
}