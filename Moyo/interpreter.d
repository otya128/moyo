module moyo.interpreter;
import moyo.tree;
import moyo.mobject;
import core.exception;
import std.conv;
import std.container;
const string[6] ops = ["+","-","*","/","%"];
const string[6] ops2 = ["Plus","Minus","Mul","Div","Mod"];
template GenOperator(string type, string op)
{
    const char[] GenOperator =
        "case TokenType." ~ type ~ " - TokenType.OP:" ~  
        "return op1" ~ op ~ "op2;";
}
template GenOperatorFunction(TokenType type, string op)
{
    const char[] GenOperatorFunction =
        "case TokenType." ~ type.to!(const char[]) ~ " - TokenType.OP:" ~  
        "return op1.op" ~ op ~ "(op2);";
}
template GenOperatorFunction(TokenType type)
{
    const char[] GenOperatorFunction =
        "case TokenType." ~ type.to!(const char[]) ~ " - TokenType.OP:" ~  
        "return op1.op" ~ type.to!(const char[]) ~ "(op2);";
}
class RuntimeException : Exception
{
    this(wstring msg)
    {
        super(msg.to!string);
    }
    this(string msg)
    {
        super(msg);
    }
}
class VariableUndefinedException : RuntimeException
{
    this(mstring var)
    {
        super(var ~ " is undefined");
    }
}
struct Variables
{
    this(Variables* v)
    {
        parent = v;
    }
    MObject[mstring] var;
    Variables* parent = null;
    Variables* global = null;
    protected MObject parentGet(mstring str)
    {
        if(!parent) throw new VariableUndefinedException(str);
        return parent.get(str);
    }
    public MObject get(mstring str)
    {
        MObject* mptr;
        if((mptr = str in var) is null)
        {
            if(!parent) throw new VariableUndefinedException(str);
            return parent.get(str);
        }
        else
        {
            return *mptr;
        }
        //var.byKey(str);
        //MObject mob = this.var.get(str, parentGet(str));
        //return var[str];
    }
    public void define(mstring str, ref MObject ret)
    {
        var[str] = ret;
    }
    public void set(mstring str, ref MObject ret)
    {
        var[str] = ret;
    }
    //このスコープをグローバルとして初期化
    void initGlobal()
    {
        var["print"] = moyo.library.printFunc;
        var["null"] = MObject();
        var.rehash();
    }
}
class Interpreter
{
    this()
    {
        auto global = new Variables();
        global.initGlobal();
        variable.global = global;
    }
    this(Variables* parent)
    {
        variable.parent = parent;
    }
    this(Interpreter parent)
    {
        variable.parent = &parent.variable;
        variable.global = parent.variable.global;
    }
    Variables variable;
    void runStatement(Statement statement, ref MObject value)
    {
        if(!statement) return;
        switch(statement.Type)
        {
            case NodeType.ExpressionStatement:
                value = Eval((cast(ExpressionStatement)statement).expression);
                break;
            case NodeType.DefineVariable:
                auto dv = cast(DefineVariable)statement;
                int siz = dv.variables.length;
                MObject mob;
                for(int i = 0;i < siz;i++)
                {
                    mob = Eval(dv.initExpressions[i]);
                    this.variable.define(dv.variables[i].name, mob);
                }
                break;
            case NodeType.If:
                auto statementIf = cast(If)statement;
                MObject cond;
                cond = Eval(statementIf.condition);
                if(cond.opBool)
                {
                    auto interpreter = new Interpreter(this);
                    interpreter.runStatement(statementIf.thenStatement, value);
                }
                else
                {
                    if(statementIf.elseStatement)
                    {
                        auto interpreter = new Interpreter(this);
                        interpreter.runStatement(statementIf.elseStatement, value);
                    }
                }
                break;
            case NodeType.Statements:
                auto statements = cast(Statements)statement;
                foreach(s; statements.statements)
                {
                    runStatement(s, value);
                }
                break;
            case NodeType.For:
                //for(a;b;c){d}
                //for(1;2; ){3}
                //for( ;5;4){6}
                //for( ;9;8){7}
                auto statementFor = cast(For)statement;
                auto interpreter = new Interpreter(this);
                interpreter.runStatement(statementFor.initStatement, value);
                bool infloop;
                if(!statementFor.condition)
                {
                    infloop = true;
                }
                else
                {
                    //条件式がfalseなら
                    if(!interpreter.Eval(statementFor.condition).opBool())
                        break;//おしまい
                }
                while(true)
                {
                    interpreter.runStatement(statementFor.statement, value);
                    if(infloop) continue;
                    interpreter.Eval(statementFor.loop);
                    //条件式がfalseなら
                    if(!interpreter.Eval(statementFor.condition).opBool())
                        break;//おしまい
                }
                break;
            default:
                throw new RuntimeException("What");
        }
    }
    public MObject Eval(Expression tree)
    {
        if(!tree)
        {
            alias RuntimeException atou;
            atou re = new RuntimeException("What~!!");
            throw re;
        }
        switch(tree.Type)
        {
            case NodeType.Variable:
                return variable.get((cast(Variable)tree).name);
            case NodeType.BinaryOperator:
                BinaryOperator bo = cast(BinaryOperator)tree;
                switch(bo.type)
                {
                    case TokenType.Assign:
                        Variable v = cast(Variable)bo.OP1;
                        MObject op2 = Eval(bo.OP2);
                        variable.set(v.name, op2);
                        return op2;
                    case TokenType.LeftParenthesis:
                        MObject op1 = Eval(bo.OP1);
                        if(op1.Type != ObjectType.Function)
                        {
                            throw new RuntimeException(op1.toString ~ " is not function");
                        }
                        FunctionArgs FA = cast(FunctionArgs)bo.OP2;
                        Array!MObject args;
                        foreach(tr; FA.args)
                        {
                            args.insertBack(Eval(tr));
                        }
                        return op1.value.Func(args);
                    default:
                }
                MObject op1 = Eval(bo.OP1);
                MObject op2 = Eval(bo.OP2);
                switch(bo.type - TokenType.OP)
                {
                    mixin(GenOperator!("Plus", "+"));
                    mixin(GenOperator!("Minus", "-"));
                    mixin(GenOperator!("Mul", "*"));
                    mixin(GenOperator!("Div", "/"));
                    mixin(GenOperator!("Mod", "%"));
                    mixin(GenOperatorFunction!(TokenType.Equals, "Equal"));
                    //IDE補完が効いて楽
                    mixin(GenOperatorFunction!(TokenType.NotEquals, "NotEqual"));
                    mixin(GenOperatorFunction!(TokenType.Less));
                    mixin(GenOperatorFunction!(TokenType.Greater));
                    mixin(GenOperatorFunction!(TokenType.LessOrEqual));
                    mixin(GenOperatorFunction!(TokenType.GreaterOrEqual));
                    //mixin(GenOperator!("Cmp", "=="));
                    default:
                }
                throw new Exception("What????");
            case NodeType.Constant:
                return (cast(Constant)tree).value;
            default:
                throw new RuntimeException("What");
        }
    }
}