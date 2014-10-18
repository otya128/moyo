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
}
enum TokenType
{
    None=0b00,
    Iden=0b01,
    Number=0b10,
    String=0b11,
    RightParenthesis = 0b101,//)
    Comma = 0b110,
    Plus=0b10000,
    OP = 0b10000,
    Minus=OP|1,
    Mul=OP|2,
    Div=OP|3,
    Mod=OP|4,
    Assign = OP | 5,
    LeftParenthesis = OP | 6,//(
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
    ObjectType valueType;
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
}
class Statements : Statement
{
    public override @property NodeType Type(){return NodeType.Statements;}
    Array!Statement statements;
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
}
unittest
{
    Tree bo = cast(Tree)new BinaryOperator(null, null, TokenType.None);

    assert(bo.Type == NodeType.BinaryOperator);
    assert(true);
}