module moyo.mobject;
import std.conv;
alias wstring mstring;
enum ObjectType : byte
{
    Void,
    Object,
    Int,
    Boolean,
    String,
    Function,
    ClassInstance,
    Class,//type only
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
    MClass Class;
    MClassInstance Object;
}
//alias typeof(&opAddInt32) operator;//MObject function (ref MObject, ref MObject) operator;
alias moyo.interpreter.Interpreter Interpreter;
alias moyo.interpreter.Variables Variables;
alias moyo.interpreter.VariableUndefinedException VariableUndefinedException;
alias moyo.interpreter.RuntimeException RuntimeException;

class MObject__vfptr
{
    //__vtbl
    mstring function(ref MObject) toString;
    alias operator = MObject function(ref MObject, ref MObject);
    operator opAdd = &NoImplFunctionA2;
    operator opSub = &NoImplFunctionA2;
    operator opMul = &NoImplFunctionA2;
    operator opDiv = &NoImplFunctionA2;
    operator opMod = &NoImplFunctionA2;
    operator opEquals = &NoImplFunctionA2;
    operator opNotEquals = &NoImplFunctionA2;
    operator opLess = &NoImplFunctionA2;
    operator opGreater = &NoImplFunctionA2;
    operator opLessOrEqual = &NoImplFunctionA2;
    operator opGreaterOrEqual = &NoImplFunctionA2;
    bool function(ref MObject) opBool;
    MObject function(ref MObject op1, ArgsType args, Interpreter parent) opCall;
    ObjectType type;
    BaseClassInfo classInfo;
    protected this(){};
    public this(ObjectType type, BaseClassInfo info, mstring function(ref MObject) to_s,
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
        this.classInfo = info;
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
        this.classInfo = new ObjectClassInfo();
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
    static this()
    {
        vfptrs = initvfptrs(new MObject__vfptr[ObjectType.max + 1]);
    }
}
//alias vfptrs = MObject__vfptr.vfptrs;
MObject__vfptr[] vfptrs;//[ObjectType.max + 1]
MObject__vfptr[] initvfptrs(MObject__vfptr[] vfptrs)
{
    objectClassInfo = new MClassInfo("Object");
    objectClassInfo.instance.addFunction("ToString", ObjectClassInfo.retStringArgVoid, ObjectClassInfo.to_s);
    vfptrs[ObjectType.Void] = new MObject__vfptr(ObjectType.Void, new ObjectClassInfo(), &toStringTypename!"Void");
    vfptrs[ObjectType.Object] = new MObject__vfptr(ObjectType.Object, new ObjectClassInfo(), &toStringObject, &NoImplFunctionA2);
    vfptrs[ObjectType.Int] = new MObject__vfptr(ObjectType.Int, new ObjectClassInfo(), &toStringInt32, &opAddInt32, &opSubInt32, &opMulInt32, &opDivInt32, &opModInt32,
                                                (ref MObject op1, ref MObject op2)=>
        MObject(op1.value.Int32 == op2.value.Int32),
                                                &opNotEqualInt32, &opLessInt32, &opGreaterInt32, &opLessOrEqualInt32, &opGreaterOrEqualInt32);
    vfptrs[ObjectType.Boolean] = MObject__vfptr.addOpEquals(
                                                            MObject__vfptr.addOpBool(
                                                                                     new MObject__vfptr(ObjectType.Boolean, new ObjectClassInfo(), &toStringBoolean), &opBoolBoolean),
                                                            (ref MObject op1, ref MObject op2)=>MObject(op1.value.Boolean == op2.value.Boolean)
                                                            );
    vfptrs[ObjectType.String] = MObject__vfptr.addOpEquals(
                                                           new MObject__vfptr(ObjectType.String, new ObjectClassInfo(), &toStringString, &opAddString),
                                                           (ref MObject op1, ref MObject op2)=>MObject(op1.value.String == op2.value.String)
                                                               );
    vfptrs[ObjectType.Function] = new MObject__vfptr(&toStringFunction, &Function.opCallFunction);
    vfptrs[ObjectType.Class] = new MClass__vfptr();
    vfptrs[ObjectType.ClassInstance] = new MClassInstance__vfptr();
    return vfptrs;
}
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
    public this(MClass value)
    {
        this.value.Class = value;
        this.type = ObjectType.Class;
    }
    public this(MClassInstance value)
    {
        this.value.Object = value;
        this.type = ObjectType.ClassInstance;
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
    public MObject opDot(mstring name)
    {
        return vfptrs[type].classInfo.getMember(name, this);
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
    alias moyo.tree.DefineFunction DefineFunction;
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
abstract class BaseClassInfo
{
    ValueType getMemberType(mstring);
    MObject getMember(mstring, ref MObject);
    //ValueType getFunctionType(mstring);
    //MObject getFunction(mstring, ref MObject);
}
//primitive
alias moyo.tree.StaticVariable StaticVariable;
class ObjectClassInfo : BaseClassInfo
{
    static MObject to_s = MObject(new NativeFunction(&ObjectToString, "ToString"));
    StaticVariable membersType;
    Variables members;
    static ValueType retStringArgVoid = ValueType(ObjectType.Function, new FunctionClassInfo(ValueType(ObjectType.String)));
    static MObject ObjectToString(Array!MObject mob)
    {
        if(mob.length != 1)
        {
            throw new RuntimeException("length");
        }
        return MObject(mob[0].toString());
    }
    this()
    {
        membersType.define("ToString", retStringArgVoid);
        members.define("ToString", to_s);
    }
    override ValueType getMemberType(mstring str)
    {
        return membersType.get(str);
    }
    override MObject getMember(mstring str, ref MObject)
    {
        return members.get(str);
    }
}
class FunctionClassInfo : BaseClassInfo
{
    Array!ValueType args;
    ValueType retType;
    this(){}
    this(ValueType retType)
    {
        this.retType = retType;
    }
    override ValueType getMemberType(mstring name)
    {
        if(name == "ToString")
        {
            return ObjectClassInfo.retStringArgVoid;
        }
        return ValueType.errorType;
    }
    override MObject getMember(mstring name, ref MObject)
    {
        if(name == "ToString")
        {
            return ObjectClassInfo.to_s;
        }
        throw new VariableUndefinedException(name);
    }
}
__gshared MClassInfo objectClassInfo;
///class info
class MClassInfo : BaseClassInfo
{
    MClassInfo parentClass;
    Variables staticMembers;
    StaticVariable staticMembersType;
    MInstanceInfo instance;
    mstring name;
    this(MClassInfo parent, mstring name)
    {
        this.name = name;
        if(parent)
        {
            instance = new MInstanceInfo(parent.instance, name);
            staticMembers.parent = &parent.staticMembers;
            this.parentClass = parent;
        }
        else
        {
            instance = new MInstanceInfo(name);
        }
    }
    this(mstring name)
    {
        this(objectClassInfo, name);//親クラスをObjectに設定します。
    }
    MClass create()
    {
        return new MClass(this);
    }
    override ValueType getMemberType(mstring str)
    {
        return staticMembersType.get(str);
    }
    override MObject getMember(mstring str, ref MObject)
    {
        return staticMembers.get(str);
    }
    static this()
    {
    }
}
class MInstanceInfo : BaseClassInfo
{
    StaticVariable members;
    StaticVariable functionsType;
    Variables functions;
    MInstanceInfo parent;
    mstring name;
    this(MInstanceInfo para, mstring name)
    {
        parent = para;
        members.parent = &parent.members;
        functions.parent = &parent.functions;
        functionsType.parent = &parent.functionsType;
        this.name = name;
    }
    this(mstring name)
    {
        this.name = name;
    }
    override ValueType getMemberType(mstring str)
    {
        return members.get(str);
    }
    override MObject getMember(mstring str, ref MObject op)
    {
        return op.value.Object.getMember(str, op);
    }
    void addMember(mstring name, ValueType vt)
    {
        members.define(name, vt);
    }
    void addFunction(mstring name, ValueType vt, ref MObject func)
    {
        functionsType.define(name, vt);
        functions.define(name, func);
    }
    MClassInstance create()
    {
        return new MClassInstance(this);
    }
}
class MClass
{
    MClassInfo classInfo;
    Variables members;
    this(MClassInfo classInfo)
    {
        this.classInfo = classInfo;
    }
}
class MClassInstance 
{
    MInstanceInfo classInfo;
    Variables members;
    this(MInstanceInfo classInfo)
    {
        this.classInfo = classInfo;
        foreach(i; this.classInfo.members.var.byKey)
        {
            members.define(i, Void);
        }
    }
    MObject getMember(mstring str, ref MObject op)
    {
        return members.get(str);
    }
    mstring toClassString()
    {
        return this.classInfo.name;
    }
}
class MClassInstance__vfptr : MObject__vfptr
{
    this()
    {
        toString = &toStr;
        this.type = ObjectType.ClassInstance;
        this.classInfo = objectClassInfo.instance;
    }
    MObject opDot(mstring name, ref MObject op)
    {
        return op.value.Object.getMember(name, op);
    }
    static mstring toStr(ref MObject op)
    {
        return op.value.Object.toClassString();
    }
}
class MClass__vfptr : MObject__vfptr
{
    this()
    {
        this.type = ObjectType.Class;
    }
    MObject opDot(mstring name, ref MObject)
    {
        return MObject();   
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
    static ValueType Object = ValueType(ObjectType.Object);
    static ValueType Int = ValueType(ObjectType.Int);
    static ValueType Boolean = ValueType(ObjectType.Boolean);
    static ValueType String = ValueType(ObjectType.String);
    static ValueType Function = ValueType(ObjectType.Function);
    string toString()
    {
        return type.to!string;
    }
    static ValueType errorType = ValueType();
    public this(ObjectType ot)
    {
        type = ot;
    }
    ObjectType type;
    BaseClassInfo classInfo;
    public this(ObjectType ot, BaseClassInfo t)
    {
        type = ot;
        classInfo = t;
    }
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
    public ValueType opDot(mstring name)
    {
        if(this.classInfo)
        {
            return this.classInfo.getMemberType(name);
        }
        return vfptrs[this.type].classInfo.getMemberType(name);
    }
    //クラスなどを実装した場合ここに記述
}