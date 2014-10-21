/**
Define syntax tree
*/
module moyo.tree;
import moyo.mobject;
import std.container;
enum NodeType
{
    Node,
    Constant,
    BinaryOperator,
    Variable,
    FunctionArgs,
    Statements,
    ExpressionStatement,
    DefineVariable,
    For,
    If,
    Return,
    Continue,
    Break,
    DefineFunction,
}
enum TokenType
{
    None=0b00,
    Iden=0b01,
    Number=0b10,
    String=0b11,
    RightParenthesis = 0b101,//)
    Comma = 0b110,
    BlockStart = 0b111,//{
    BlockEnd = 0b1000,//}
    Semicolon = 0b1001,//;
    Lambda = 0b1010,//=>
    Plus=0b10000,
    OP = 0b10000,
    Minus=OP|1,
    Mul=OP|2,
    Div=OP|3,
    Mod=OP|4,
    Assign = OP | 5,
    LeftParenthesis = OP | 6,//(
    Equals = OP | 7,//==
    NotEquals,
    Less,
    Greater,
    LessOrEqual,
    GreaterOrEqual,
    Dot,//.
}

/+
1+1
        +
       / \
       1 1
1+2+3
  +
 / \
1  +
  / \
 2   3

1+2+3
    +
   / \
  +   3
 / \  
1   2

2*2+1
  +
 / \
 * 1
/ \
2 2
+/
//
abstract class Tree
{
    public @property NodeType Type();
}
abstract class XmasTree : Tree
{
}
abstract class Expression : Tree
{
    ValueType valueType;
}
class BinaryOperator : Expression
{//override
    public override @property NodeType Type(){return NodeType.BinaryOperator;}
    Expression OP1;
    Expression OP2;
    public this(Expression op1, Expression op2, TokenType tt)
    {
        this.OP1 = op1;
        this.OP2 = op2;
        this.type = tt;
    }
    TokenType type;
}
class Constant : Expression
{
    public override @property NodeType Type(){return NodeType.Constant;}
    MObject value;
}
class Variable : Expression
{
    public override @property NodeType Type(){return NodeType.Variable;}
    mstring name;
    public this(mstring name)
    {
        this.name = name;
    }
}
class FunctionArgs : Expression
{
    import std.container;
    public override @property NodeType Type(){return NodeType.FunctionArgs;}
    Array!Expression args;
}
abstract class Statement : Tree
{
}
class ExpressionStatement : Statement
{
    public override @property NodeType Type(){return NodeType.ExpressionStatement;}
    this(Expression exp)
    {
        this.expression = exp;
    }
	Expression expression;
    public @property ValueType valueType(){return expression.valueType;}
}
class Statements : Statement
{
    public override @property NodeType Type(){return NodeType.Statements;}
    Array!Statement statements;
    StaticVariable variables;
}
///type-name variable-name[=expression][, variable-name[=expression]...]
class DefineVariable : Statement
{
    public override @property NodeType Type(){return NodeType.DefineVariable;}
    public this(mstring name)
    {
        typeName = name;
    }
    mstring typeName;
    std.container.Array!Variable variables;
    Array!Expression initExpressions;
    ValueType valueType;
    public void add(mstring name, Expression exp)
    {
        variables.insertBack(new Variable(name));
        initExpressions.insertBack(exp);
    }
}
///for(statement;expression;expression) statement|{statements}
class For : Statement
{
    public override @property NodeType Type(){return NodeType.For;}
    Statement initStatement;
    Expression condition;
    Expression loop;
    Statement statement;
}
///if expression statement|{statements} [else statement|{statements}]
class If : Statement
{
    public override @property NodeType Type(){return NodeType.If;}
    Expression condition;
    Statement thenStatement;
    Statement elseStatement;
}
///return expression
class Return : Statement
{
    public override @property NodeType Type(){return NodeType.Return;}
    Expression expression;
}
class Continue : Statement
{
    public override @property NodeType Type(){return NodeType.Continue;}
    Statement continueStatement;
}
class Break : Statement
{
    public override @property NodeType Type(){return NodeType.Break;}
    Statement breakStatement;
}

class DefineFunction : Tree
{
    public override @property NodeType Type(){return NodeType.DefineFunction;}
    Statement statement;
    mstring type;
    mstring name;
    //未解決の型
    struct VariablePair
    {
        this(mstring type, mstring name)
        {
            this.type = type;
            this.name = name;
        }
        mstring type;
        mstring name;
    }
    Array!VariablePair args;
    auto add(mstring type, mstring name)
    {
        args.insertBack(VariablePair(type, name));
    }
    ValueType valueType;
}
struct StaticVariable
{
    ValueType[mstring] var;
    this(StaticVariable* v)
    {
        parent = v;
    }
    StaticVariable* parent = null;
    StaticVariable* global = null;
    protected ValueType parentGet(mstring str)
    {
        if(!parent) throw new moyo.interpreter.VariableUndefinedException(str);
        return parent.get(str);
    }
    public ValueType* getptr(mstring str)
    {
        ValueType* mptr;
        if((mptr = str in var) is null)
        {
            if(!parent) throw new moyo.interpreter.VariableUndefinedException(str);
            return parent.getptr(str);
        }
        else
        {
            return mptr;
        }
    }
    public ValueType get(mstring str)
    {
        ValueType* mptr;
        if((mptr = str in var) is null)
        {
            if(!parent) throw new moyo.interpreter.VariableUndefinedException(str);
            return parent.get(str);
        }
        else
        {
            return *mptr;
        }
    }
    public void define(mstring str, ValueType ret)
    {
        var[str] = ret;
    }
    public void set(mstring str, ValueType ret)
    {
        if(str !in var)
        {
            if(!parent) throw new moyo.interpreter.VariableUndefinedException(str);
            return parent.set(str, ret);
        }
        var[str] = ret;
    }
    //このスコープをグローバルとして初期化
    void initGlobal()
    {
        var["print"] = ValueType(ObjectType.Function, new FunctionClassInfo());
        var["null"] = ValueType();
        var["true"] = ValueType(ObjectType.Boolean);
        var["false"] = ValueType(ObjectType.Boolean);
        var.rehash();
    }
    static ValueType[mstring] types;
    static this()
    {
        types = [
            "int": ValueType(ObjectType.Int),
            "bool": ValueType(ObjectType.Boolean),
            "string": ValueType(ObjectType.String),
        ];
        types.rehash();
    }
    static ValueType nameToType(mstring mstr)
    {
        ValueType* ms = (mstr in types);
        return ms ? *ms : ValueType.errorType;
    }
}
unittest
{
    Tree bo = cast(Tree)new BinaryOperator(null, null, TokenType.None);

    assert(bo.Type == NodeType.BinaryOperator);
    assert(true);
}