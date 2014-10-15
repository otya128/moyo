module moyo.tree;
import moyo.mobject;
enum NodeType
{
    Node,
    Constant,
    Expression,
    BinaryOperator,
    Identifier,
}
enum TokenType
{
    None=0b00,
    Iden=0b01,
    Number=0b10,
    String=0b11,
    LeftParenthesis = 0b100,//(
    RightParenthesis = 0b101,//)
    Plus=0b10000,
    OP = 0b10000,
    Minus=OP|1,
    Mul=OP|2,
    Div=OP|3,
    Mod=OP|4,
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
class Tree
{
    public @property NodeType Type(){return NodeType.Node;}
}
class Expression : Tree
{
    public override @property NodeType Type(){return NodeType.Expression;}
    Tree OP1;
}
class BinaryOperator : Tree
{//override
    public override @property NodeType Type(){return NodeType.BinaryOperator;}
    Tree OP1;
    Tree OP2;
    public this(Tree op1, Tree op2, TokenType tt)
    {
        this.OP1 = op1;
        this.OP2 = op2;
        this.type = tt;
    }
    TokenType type;
}
class Constant : Tree
{
    public override @property NodeType Type(){return NodeType.Constant;}
    MObject value;
}
class Identifier : Tree
{
    public override @property NodeType Type(){return NodeType.Identifier;}
    mstring name;
    
}
unittest
{
    Tree bo = cast(Tree)new BinaryOperator(null, null, TokenType.None);

    assert(bo.Type == NodeType.BinaryOperator);
    assert(true);
}