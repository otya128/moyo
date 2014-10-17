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
    ASCII = 0b000,
    multiByte = 0b000,
    UTF8 = 1,
    shift_jis = 2,
    wide = 0b10000,
    UTF16 = 0b10000,
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
    int line;
    int linepos;
    MObject constant;
    mstring name;
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
    int linepos;
    int length;
    string msg;
    this(string message)
    {
        this.msg = message;
    }
    this(string message, TokenList tl)
    {
        msg = message;
        this.line = tl.line;
        this.linepos = tl.linepos;
        this.pos = tl.position;
        this.length = tl.length;
    }
    this(string message, int line, int pos, int length, int linepos)
    {
        msg = message;
        this.linepos = linepos;
        this.line = line;
        this.pos = pos;
        this.length = length;
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
int AssignRank = 16;
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
        case TokenType.Assign - TokenType.OP:
            return 16;
        default:
            throw new ParseException("Invalid Operator: " ~ to!string(type), type);
    }
}
class Parser
{
    Stream input;
    Encoding enc;
    string name;
    public this(Stream s, Encoding e, string name)
    {
        input = s;
        enc = e;
        this.name = name;
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
                write('{');
                stdout.flush();
                to_s((cast(Expression)tr).OP1);
                write('}');
                break;
            case NodeType.BinaryOperator:
                write("{type:");
                write((cast(BinaryOperator)tr).type);
                write(',');
                stdout.flush();
                write("[");
                to_s((cast(BinaryOperator)tr).OP1);
                write(',');
                stdout.flush();
                to_s((cast(BinaryOperator)tr).OP2);
                write("]}");
                break;
            case NodeType.Constant:
                write((cast(Constant)tr).value);
                break;
            case NodeType.Variable:
                write((cast(Variable)tr).name);
                break;
            case NodeType.FunctionArgs:
                write('[');
                foreach(t; ((cast(FunctionArgs)tr).args))
                {
                    to_s(t);
                    write(',');
                }
                write(']');
                break;
            default:
                
        }
        stdout.flush();
    }
    Variables global;
    public MObject ParseAndEval()
    {
        auto tl = Lex();
        auto exp = parseExpression(tl);//new Expression();
        //Tree tree = expression(tl, exp);
        ERROR();
        global.initGlobal();
        auto moyo = new Moyo(&global);
        //to_s(exp);
        auto ret = moyo.Eval(exp);
        return ret;
    }
    //エラーだったら表示して例外投げて死ぬ
    public void ERROR()
    {
        if(errors.length > 0)
        {
            foreach(ParseError e; errors)
            {
                stderr.writefln("%s(%d): Error: %s", name, e.line, e.msg);
                stderr.writefln(">%s", getLine(input, e.pos, e.length));
                stderr.write(' ');
                for(int i = 0;i<e.linepos;i++)
                {
                    stderr.write(' ');
                }
                for(int i = 0;i<e.length - 1;i++)
                {
                    stderr.write('^');
                }
                stderr.writeln('^');
            }
            throw new ParseException("Error!");
        }
    }
    public void Parse()
    {
        auto tl = Lex();
        foreach(TokenList i; TokenListRange(tl))
        {
            writefln("\t{constant:%s, type:%s, name:%s},", i.constant, i.type, i.name);
        }
        auto exp = parseExpression(tl);//new Expression();
        to_s(exp);
        writeln();
        ERROR();
        //Tree tree = expression(tl, exp);
        global.initGlobal();
        auto moyo = new Moyo(&global);
        writeln();
        auto ret = moyo.Eval(exp);
        writeln();
        writeln(ret);
    }
    public Tree expression(ref TokenList tl)
    {
        if(!tl)
        {
            Error(new ParseError("Syntax Error(Expression) parser bug?"));
            return null;
        }//throw new ParseException("Syntax Error(Expression)", tl);
        Constant cons;
        Tree tree;
        switch(tl.type)
        {
            case TokenType.Number:
                cons = new Constant();
                cons.value = tl.constant;
                tree = cons;
                break;
            case TokenType.LeftParenthesis:
                auto tk = tl.next;
                tree = parseExpression(tk);
                tl = tk;
                break;
            case TokenType.Iden:
                tree = new Variable(tl.name);
                break;
            default:
                Error(new ParseError("Syntax Error(Expression)", tl));
                return null;
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
    Tree parseExpression(ref TokenList tl)
    {
        Tree tree;
        Tree op1 = expression(tl);
        if(!tl) return op1;
        tl = tl.next;
        if(!tl) return op1;
        if(!tl.type.isOperator())
        {
            if(tl.type == TokenType.Comma)
            {
                return op1;
            }
            if(tl.type == TokenType.RightParenthesis)
            {
                return op1;
            }
            Error(new ParseError("Syntax Error(Operator)", tl));
            return null;
        }
        Tree bo = new BinaryOperator(op1, null, tl.type);
        if(expression2(tl, bo)) return bo;
        if(!tl) return bo;
        expression(tl, bo);
        tree = bo;
        return tree;
    }
    auto expression2(ref TokenList tl, ref Tree tr)
    {
        BinaryOperator bo = cast(BinaryOperator)tr;
        if(bo.type == TokenType.LeftParenthesis)
        {
            parseFunction(tl, tr);
            return true;
        }
        return false;
    }
    auto parseFunction(ref TokenList tl, ref Tree tr)
    {
        BinaryOperator bo = cast(BinaryOperator)tr;
        auto func = new FunctionArgs();
        bo.OP2 = func;
        tl = tl.next;
        while(tl !is null && tl.type != TokenType.RightParenthesis)
        {
            func.args.insertBack(parseExpression(tl));
            //print(print(1),2)
            if(tl is null || tl.type == TokenType.RightParenthesis) break;
            if(tl)tl = tl.next;
        }
        if(tl)tl = tl.next;
        return func;
    }
    void expression(ref TokenList tl, ref Tree tr)
    {
        BinaryOperator bo = cast(BinaryOperator)tr;
        auto bino = bo;
        auto op = tl.type;
        tl = tl.next;
        Tree op1 = expression(tl);
        if(!tl) return;
        tl = tl.next;
        if(!tl)
        {
            bo.OP2 = op1;
            return;
        }
        if(tl.type == TokenType.Comma)
        {
            bo.OP2 = op1;
            return;
        }
        //EOT end of token
        if(!tl.type.isOperator())
        {
            if(tl.type == TokenType.RightParenthesis)
            {
                bo.OP2 = op1;
                return;
            }
            Error(new ParseError("Syntax Error(Operator): " ~ tl.type.to!string, tl));
            return;//throw new ParseException("Syntax Error(Operator)", tl);
        }
        if(expression2(tl, tr))
        {
            return;
        }
        //大きければ左再帰する
        if(tl.type.rank() >= bo.type.rank && bo.type.rank != AssignRank)
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
    enum ParserStat
    {
        None,
        Iden,
        Number,
        String,
        InvalidChar,
    }
    Array!ParseError errors;
    void Error(ParseError pe)
    {
        errors.insertBack(pe);
    }
    public TokenList Lex()
    {
        TokenList tl = null;
        TokenList front;
        bool isWide = (enc & Encoding.UTF16) == Encoding.UTF16;
        wchar inchar;
        ParserStat ps;
        int position = 0;
        MemoryStream ms = new MemoryStream();
        string s;
        int len = 0;
        int line = 0;
        int linepos = 0;
        int start = 0;
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
        void AddListIden(TokenType tt, int length, mstring iden)
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
            t.linepos = linepos - length;
            t.type = tt;
            t.name = iden;
        }
        bool isStartIden(wchar c)
        {
            return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
        }
        bool isIden(wchar c)
        {
            return (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z');
        }
        bool isIgnore(wchar c)
        {
            return c == ' ' || c == '\r' || c == '\n' || c == '\t';
        }
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
                    if(isStartIden(inchar))
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
                        case '=':
                            AddList(TokenType.Assign);
                        case ',':
                            AddList(TokenType.Comma);
                            break;
                        case '\n':
                            line++;
                            linepos = -1;
                        break;
                        case ' ':
                        case '\r':
                        case '\t':
                            break;
                        case '(':
                            AddList(TokenType.LeftParenthesis);
                            break;
                        case ')':
                            AddList(TokenType.RightParenthesis);
                            break;
                        default:
                            ps = ParserStat.InvalidChar;
                            start = linepos;
                            break;
                            //throw new ParseException("Syntax Error" ~ cast(char)inchar);
                    }
                    break;
                case ParserStat.Iden:
                    if(isIden(inchar))
                    {
                        ms.write(inchar);
                        len++;
                    }
                    else
                    {
                        mstring wstr = new mstring(len);
                        ms.position = 0;
                        for(int i = 0;i<len;i++)
                        {
                            wchar buf;
                            ms.read(wstr[i]);
                        }
                        ms.position = 0;
                        AddListIden(TokenType.Iden, len, wstr);
                        ps = ParserStat.None;
                        len = 0;
                        goto case ParserStat.None;
                    }
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
                case ParserStat.InvalidChar:
                    if(isIgnore(inchar))
                    {
                        Error(new ParseError("Syntax Error", line, position, len, position));
                        ps = ParserStat.None;
                        goto case ParserStat.None;
                    }
                    break;
                default:
            }
            linepos++;
            if(isLast)break;
            write(inchar);
            position++;
        }
        return front;
    }
    wchar getc()
    {
        if(enc & Encoding.wide)
        {
            return input.getcw;
        }
        return cast(wchar)(input.getc());
    }
    wchar getbackc()
    {
        if(enc & Encoding.wide)
        {
            input.position=input.position - 2;
            wchar c = cast(wchar)(input.getcw);
            input.position=input.position - 2;
            return c;
        }
        input.position=input.position-1;
        wchar c = cast(wchar)(input.getc);
        input.position=input.position-1;
        return c;
    }
    string getLine(Stream s, int pos, int length = 0)
    {
        s.position = pos;
        while(true)
        {
            auto c = getbackc();
            if(c == '\n' || c == '\r' || c == wchar.init || s.position == 0)
            {
                break;
            }
        }
        return cast(string)s.readLine;
    }
}