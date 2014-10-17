/**
Define syntax tree
*/
module moyo.tree;
import moyo.mobject;
enum NodeType
{
    Node,
    Constant,
    BinaryOperator,
    Variable,
    FunctionArgs,
    Statements,
    ExpressionStatement,
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
    public @property NodeType Type(){return NodeType.Node;}
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
class Statements : Tree
{
	import std.container;
    public override @property NodeType Type(){return NodeType.Statements;}
    Array!Statement statements;
}
unittest
{
    Tree bo = cast(Tree)new BinaryOperator(null, null, TokenType.None);

    assert(bo.Type == NodeType.BinaryOperator);
    assert(true);
}