module moyo.parser;
import moyo.tree;
import moyo.mobject;
import moyo.moyo;
import std.stdio;
import std.stream;
import std.ascii;
import std.conv;
enum Encoding
{
    ASCII,
    UTF16,
}
bool isOperator(TokenType tt)
{
    return !!(tt & 0b10000);
}
class TokenList
{
    TokenType type;
    TokenList next;
    int position;
    int length;
    MObject constant;
    this()
    {
        this.next = null;
    }
}
struct TokenListRange
{
    private TokenList __front;
    public this(TokenList tl)
    {
        __front = tl;
    }
    public @property TokenList front()
    {
        return __front;
    }
    public @property bool empty()
    {
        return __front is null;
    }
    public void popFront()
    {
        __front = __front.next;
    }
}
class ParseException : Exception
{
    this(string message)
    {
        super(message);
    }
}
int rank(TokenType type)
{
    //テーブル化されやすくなりたい
    switch(type - TokenType.OP)
    {
        case TokenType.Mul - TokenType.OP:
        case TokenType.Div - TokenType.OP:
        case TokenType.Mod - TokenType.OP:
            return 5;
        case TokenType.Plus - TokenType.OP:
        case TokenType.Minus - TokenType.OP:
            return 6;
        default:
            throw new ParseException("Invalid Operator: " ~ to!string(type));
    }
}
class Parser
{
    enum ParserStat
    {
        None,
        Iden,
        Number,
        String,
    }
    InputStream input;
    Encoding enc;
    public this(InputStream s, Encoding e)
    {
        input = s;
        enc = e;
    }
    void to_s(Tree tr)
    {
        if(!tr)
        {
            write("null");
            stdout.flush();
            return;
        }
        switch(tr.Type)
        {
            case NodeType.Expression:
                write('(');
                stdout.flush();
                to_s((cast(Expression)tr).OP1);
                write(')');
                break;
            case NodeType.BinaryOperator:
                write('(');
                write((cast(BinaryOperator)tr).type);
                write(' ');
                stdout.flush();
                to_s((cast(BinaryOperator)tr).OP1);
                write(' ');
                stdout.flush();
                to_s((cast(BinaryOperator)tr).OP2);
                write(')');
                break;
            case NodeType.Constant:
                write((cast(Constant)tr).value);
                break;
                
        }
        stdout.flush();
    }
    public void Parse()
    {
        auto tl = Lex();
        auto exp = new Expression();
        Tree tree = expression(tl, exp);
        auto moyo = new Moyo();
        to_s(exp);
        auto ret = moyo.Eval(exp);
        writeln(ret);
    }
    public Tree expression(TokenList tl)
    {
        if(!tl)throw new ParseException("Syntax Error(Expression)");
        Constant cons;
        Tree tree;
        switch(tl.type)
        {
            case TokenType.Number:
                cons = new Constant();
                cons.value = tl.constant;
                tree = cons;
                break;
            default:
                throw new ParseException("Syntax Error(Expression)");
        }
        return tree;
    }
    /+
    []
    exp
    1
    exp
    +1
    exp2
    bo?+1
    set bo1+1

    1+2+3
    []
    1
    +2
    bo?+2
    +3
    bo?+3
    set (bo?+2)+3
    ret bo?+2
    set (bo1+2)+3
    +/
    public Tree expression(TokenList tl, Tree parent)
    {
        return expressionLeft(tl, parent);
        /*
        Tree op1, op2;
        Constant cons;
        Tree operator;
        BinaryOperator bo;
        op1 = expression(tl);
        //get operator
        tl = tl.next;
        if(!tl) return op1;//throw new ParseException("Syntax Error(Operator)");
        if(!tl.type.isOperator())
        {
            throw new ParseException("Syntax Error(Operator)");
        }
        auto op = tl;
        tl = tl.next;
        bo = new BinaryOperator(op1, op2, op.type); 
        bo.OP2 = expression(tl, parent);
        return bo;*/
    }
    //<-左の方
    Tree expressionLeft(TokenList tl, Tree parent)
    {
        Tree op1 = expression(tl);
        //get operator
        tl = tl.next;
        if(!tl) return op1;
        Tree ret = expressionRight(tl, parent);
        if(ret.Type == NodeType.BinaryOperator)
        {
            BinaryOperator bo = cast(BinaryOperator)ret;
            bo.OP1 = op1;
            if(!(cast(Expression)parent).OP1)(cast(Expression)parent).OP1 = bo;
        }
        return ret;
    }
    //右の方->
    Tree expressionRight(TokenList tl, Tree parent)
    {
        Tree ret;
        
        if(!tl.type.isOperator())
        {
            throw new ParseException("Syntax Error(Operator)");
        }
        auto op = tl;
        tl = tl.next;
        BinaryOperator bo = new BinaryOperator(null, null, op.type); 
        bo.OP2 = expression(tl);
        auto tk = tl.next;
        if(tk && tk.type.isOperator())
        {
            if(tk.type.rank() >= op.type.rank()) 
            {
                BinaryOperator bo2 = cast(BinaryOperator)(expressionRight(tk, parent));
                Constant op1 = cast(Constant)bo2.OP1,op2=cast(Constant)bo2.OP2;
                bo2.OP1 = bo;
                if(!(cast(Expression)parent).OP1)(cast(Expression)parent).OP1 = bo2;
            }
            else
            {
                BinaryOperator bo2 = cast(BinaryOperator)(expressionRight(tk, parent));
                Constant opu1 = cast(Constant)bo2.OP1,opu2=cast(Constant)bo2.OP2;//3
                Constant opa1 = cast(Constant)bo.OP1,opa2=cast(Constant)bo.OP2;//2
                bo2.OP1 = opa2;
                auto test1 = bo.type;
                auto test2 = bo2.type;
                bo.OP2 = bo2;
                //bo = bo2;
                /*
                bo2.OP2 = bo;
                if(!(cast(Expression)parent).OP1)(cast(Expression)parent).OP1 = bo;*/
            }
        }
        //else
       //if(!(cast(Expression)parent).OP1)(cast(Expression)parent).OP1 = bo;
        ret = bo;
        return ret;
    }
    public TokenList Lex()
    {
        TokenList tl = null;
        TokenList front;
        bool isWide = enc == Encoding.UTF16;
        wchar inchar;
        ParserStat ps;
        int position;
        MemoryStream ms = new MemoryStream();
        void AddList(TokenType tt, int length = 1, MObject constant = MObject.init)
        {
            auto t = new TokenList();
            if(tl is null)
            {
                tl = t;
                front = t;
            } 
            else tl.next = t;
            tl = t;
            t.position = position - length + 1;
            t.length = 1;
            t.type = tt;
            t.constant = constant;
        }
        string s;
        int len = 0;
        while(true){
            bool isLast = false;
            if(isWide)
            {
                inchar = input.getcw();
                if(inchar == wchar.init)isLast = true;
            }
            else
            {
                inchar = cast(wchar)input.getc();
                if(inchar == char.init)isLast = true;
            }
            switch(ps)
            {
                case ParserStat.None:
                    if(isLast)break;
                    if(isAlpha(inchar))
                    {
                        ps = ParserStat.Iden;
                        goto case ParserStat.Iden;
                    }
                    if(isDigit(inchar))
                    {
                        ps = ParserStat.Number;
                        goto case ParserStat.Number;
                    }
                    switch(inchar)
                    {
                        case '+':
                            AddList(TokenType.Plus);
                            break;
                        case '-':
                            AddList(TokenType.Minus);
                            break;
                        case '*':
                            AddList(TokenType.Mul);
                            break;
                        case '/':
                            AddList(TokenType.Div);
                            break;
                        case '%':
                            AddList(TokenType.Mod);
                            break;
                            case '\n':
                            case ' ':
                            case '\r':
                                break;
                        default:
                            throw new ParseException("Syntax Error" ~ cast(char)inchar);
                    }
                    break;
                case ParserStat.Iden:
                        
                    break;
                case ParserStat.Number:
                    if(isDigit(inchar))
                    {
                        ms.write(inchar);
                        len++;
                    }
                    else
                    {
                        ms.position = 0;
                        int int_num = 0;
                        for(int i = 0;i<len;i++)
                        {
                            wchar buf;
                            int_num *= 10;
                            ms.read(buf);
                            int_num += buf - '0';
                        }
                        ms.position = 0;
                        len = 0;
                        AddList(TokenType.Number, len, MObject(int_num));
                        ps = ParserStat.None;
                        goto case ParserStat.None;
                    }
                    break;
                default:
            }
            if(isLast)break;
            write(inchar);
            position++;
        }
        foreach(TokenList i; TokenListRange(front))
        {
            writeln(i.constant);
            writeln(i.type);
        }
        return front;
    }
}