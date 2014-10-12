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
    public void Parse()
    {
        auto tl = Lex();
        auto exp = new Expression();
        Tree tree = expression(tl, exp);
        auto moyo = new Moyo();
        auto ret = moyo.Eval(tree);
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
    public Tree expression(TokenList tl, Tree parent)
    {
        Tree op1, op2;
        Constant cons;
        Tree operator;
        BinaryOperator bo;
        op1 = expression(tl);
        //get operator
        tl = tl.next;
        if(!tl) throw new ParseException("Syntax Error(Operator)");
        if(!tl.type.isOperator())
        {
            throw new ParseException("Syntax Error(Operator)");
        }
        tl = tl.next;
        bo = new BinaryOperator(op1, op2, tl.type); 
        bo.OP2 = expression(tl);
        return bo;
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