module moyo.tree;
import moyo.mobject;
enum NodeType
{
    Node,
    Constant,
    Expression,
    BinaryOperator,
}
enum TokenType
{
    None=0b00,
    Iden=0b01,
    Number=0b10,
    String=0b11,
    Plus=0b10000,
    Minus=0b10001,
    Mul=0b10010,
    Div=0b10011,
    Mod=0b10100,
}

/+
1+1
        +
       / \
       1 1
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
unittest
{
    Tree bo = cast(Tree)new BinaryOperator(null, null, TokenType.None);

    assert(bo.Type == NodeType.BinaryOperator);
    assert(true);
}