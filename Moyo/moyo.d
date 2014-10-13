module moyo.moyo;
import moyo.tree;
import moyo.mobject;
template GenOperator(string type, string op)
{
    const char[] GenOperator =
        "case TokenType." ~ type ~ " - TokenType.OP:" ~  
        "return op1" ~ op ~ "op2;";
}
class Moyo
{
    public MObject Eval(Tree tree)
    {
        switch(tree.Type)
        {
            //debug!
            case NodeType.Expression:
                return Eval((cast(Expression)tree).OP1);
                break;
            case NodeType.BinaryOperator:
                BinaryOperator bo = cast(BinaryOperator)tree;
                MObject op1 = Eval(bo.OP1);
                MObject op2 = Eval(bo.OP2);
                switch(bo.type - TokenType.OP)
                {
                    mixin(GenOperator!("Plus", "+"));
                    mixin(GenOperator!("Minus", "-"));
                    mixin(GenOperator!("Mul", "*"));
                    mixin(GenOperator!("Div", "/"));
                    mixin(GenOperator!("Mod", "%"));
                }
                throw new Exception("What????");
            case NodeType.Constant:
                return (cast(Constant)tree).value;
        }
    }
}