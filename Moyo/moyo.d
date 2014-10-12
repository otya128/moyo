module moyo.moyo;
import moyo.tree;
import moyo.mobject;
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
                return MObject(op1.value.Int32+op2.value.Int32);
                break;
            case NodeType.Constant:
                return (cast(Constant)tree).value;
        }
    }
}