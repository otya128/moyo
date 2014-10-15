module moyo.parser;
import moyo.tree;
import moyo.mobject;
import moyo.moyo;
import std.stdio;
import std.stream;
import std.ascii;
import std.conv;
import std.container;
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
static void nextToken(ref TokenList tl)
{
    tl = tl.next;
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
class ParseError
{
    int line;
    int pos;
    string msg;
    this(string message, int line, int pos)
    {
        msg = message;
        this.line = line;
        this.pos = pos;
    }
}
class ParseException : Exception
{
    this(string message)
    {
        super(message);
    }
    this(string message, TokenType tt)
    {
        super(message);
    }
    this(string message, TokenList tl)
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
            throw new ParseException("Invalid Operator: " ~ to!string(type), type);
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
    public MObject ParseAndEval()
    {
        auto tl = Lex();
        auto exp = parseExpression(tl);//new Expression();
        //Tree tree = expression(tl, exp);
        auto moyo = new Moyo();
        to_s(exp);
        auto ret = moyo.Eval(exp);
        return ret;
    }
    public void Parse()
    {
        auto tl = Lex();
        auto exp = parseExpression(tl);//new Expression();
        //Tree tree = expression(tl, exp);
        auto moyo = new Moyo();
        to_s(exp);
        auto ret = moyo.Eval(exp);
        writeln(ret);
    }
    public Tree expression(TokenList tl)
    {
        if(!tl)throw new ParseException("Syntax Error(Expression)", tl);
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
                throw new ParseException("Syntax Error(Expression)", tl);
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
    /+
    2+3*4+5
    ((2+(3*4))+5)
          +
         / \
        +   5
       / \
      2   *
         / \
        3   4
    ((3*4)+5) 2+3*4+5
    (2+(3*4)) 2+3*4
    ((3*4)+5) 3*4+5

    (((2+3)*4)+5)25
    +/
    Tree parseExpression(TokenList tl)
    {
        Tree tree;
        Tree op1 = expression(tl);
        tl = tl.next;
        if(!tl.type.isOperator())
        {
            throw new ParseException("Syntax Error(Operator)", tl);
        }
        Tree bo = new BinaryOperator(op1, null, tl.type);
        expression(tl, bo);
        tree = bo;
        return tree;
    }
    void expression(TokenList tl, ref Tree tr)
    {
        BinaryOperator bo = cast(BinaryOperator)tr;
        auto bino = bo;
        auto op = tl.type;
        tl = tl.next;
        Tree op1 = expression(tl);
        tl = tl.next;
        if(!tl)
        {
            if(bo.OP2)bo.OP1 = op1;
                else bo.OP2 = op1;
            return;
        }
        //EOT end of token
        if(!tl.type.isOperator())
        {
            throw new ParseException("Syntax Error(Operator)", tl);
        }
        //大きければ左再帰する
        if(tl.type.rank() >= bo.type.rank)
        {
            bo.OP2 = op1;
           // bo.OP1 = ;
            bo = new BinaryOperator(null, null, tl.type);
            bo.OP1 = bino;
            tr = bo;
            expression(tl, tr);
        }
        else//右再帰 
        {
            auto bi = new BinaryOperator(op1, null, tl.type);
            bo.OP2 = bi;
            Tree t = bo.OP2;
            expression(tl, t);
            bo.OP2 = t;
        }
    }
/+
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
            writeln("end");
            to_s(bo);
            writeln("end");
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
            writef("op%s ,tk%s\n", op.type, tk.type);
            if(tk.type.rank() >= op.type.rank()) 
            {
                BinaryOperator bo2 = cast(BinaryOperator)(expressionRight(tk, parent));
                Constant op1 = cast(Constant)bo2.OP1,op2=cast(Constant)bo2.OP2;
                bo2.OP1 = bo;
               // if(!(cast(Expression)parent).OP1)(cast(Expression)parent).OP1 = bo2;
                write("Botk.type.rank() >= op.type.rank())\n");to_s(bo);
                writeln();
                to_s(bo2);
                writeln();//writefln("bo:OP1 %s,OP2 %s, bo2:OP1 %s, OP2 %s", to_str(bo.OP1), to_str(bo.OP2), to_str(bo2.OP1), to_str(bo2.OP2));
            }
            else
            {
                BinaryOperator bo2 = cast(BinaryOperator)expressionRight(tk,parent);//(expressionRight(tk, parent));
                write("else\n");to_s(bo);
                writeln();
                to_s(bo2);
                writeln();
                Constant opu1 = cast(Constant)bo2.OP1,opu2=cast(Constant)bo2.OP2;//3
                Constant opa1 = cast(Constant)bo.OP1,opa2=cast(Constant)bo.OP2;//2
               /+ bo2.OP1 = opa2;
                auto test1 = bo.type;
                auto test2 = bo2.type;
              ///  return bo;
               // //bo.OP2 = bo2;
                /+
                opPlus ,tkMul
                opMul ,tkPlus
                Botk.type.rank() >= op.type.rank())
                (Mul null 4)
                (Plus (Mul null 4) 5)
                else
                (Plus null 3<-????)
                (Mul (Plus null 3) 4)
                end
                (Plus 2 3)end
                ((Plus (Mul (Plus 2 3) 4) 5))25
                +/
                bo2.OP1 = bo;//opu1;
                +/
                bo.OP2 = bo2;
                auto opu1j = bo2.OP1,opu2j=bo2.OP2;//3
                auto opa1m = bo.OP1,opa2m=bo.OP2;//2
                auto bop = bo2.type, boi = bo.type;
                write("else\n");to_s(bo);
                writeln();
                to_s(bo2);
                writeln();
                bo.OP1 = opu1j;
                bo.OP2 = opu2j;
                bo2.OP1 = opa1m;
                bo2.OP2 = bo;
                bo2.type = boi;
                bo.type = bop;
                write("else\n");to_s(bo);
                writeln();
                to_s(bo2);
                writeln();
                writefln("====%s,%s====", bo.type, bo2.type);
                if(!(cast(Expression)parent).OP1)(cast(Expression)parent).OP1 = bo2;//2;// bo=bo2;
                return bo2;
                //bo = bo2;
                /*
                bo2.OP2 = bo;
                if(!(cast(Expression)parent).OP1)(cast(Expression)parent).OP1 = bo;*/
            }
        }
        //else
       if(!(cast(Expression)parent).OP1)(cast(Expression)parent).OP1 = bo;
        ret = bo;
        return ret;
    }+/
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
        Array!ParseError errors;
        void Error(ParseError pe)
        {
            errors.insertBack(pe);
        }
        string s;
        int len = 0;
        int line = 0;
        int pos = 0;
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
                                line++;
                                pos = -1;
                            break;
                            case ' ':
                            case '\r':
                                break;
                        default:
                            Error(new ParseError("Syntax Error" ~ cast(char)inchar, line, pos));
                            break;
                            //throw new ParseException("Syntax Error" ~ cast(char)inchar);
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
            pos++;
            if(isLast)break;
            write(inchar);
            position++;
        }
        foreach(TokenList i; TokenListRange(front))
        {
            writeln(i.constant);
            writeln(i.type);
        }
        if(errors.length > 0)
        {
            foreach(ParseError e; errors)
            {
                writefln("(%d): Error: %s", e.line, e.msg);
            }
            throw new ParseException("Error!");
        }
        return front;
    }
}