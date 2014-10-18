module moyo.parser;
import moyo.tree;
import moyo.mobject;
import moyo.interpreter;
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
bool isExpression(TokenType tt)
{
    return tt.isOperator() || tt <= TokenType.String;
}
Reserved[mstring] reservedTable;
enum Reserved : byte
{
    None,
    If,
    Else,
    For
}
class TokenList
{
    static this()
    {
        reservedTable = [
            "if": Reserved.If,
            "else": Reserved.Else,
            "for": Reserved.For,
        ];
        reservedTable.rehash();
    }
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
    }
    this(mstring name)
    {
        this.name = name;
        auto res = (name in reservedTable);
        reserved = res ? *res : Reserved.None;
    }
    Reserved reserved;
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
    static Parser fromFile(string name, Encoding e = Encoding.ASCII)
    {
        return new Parser(new std.stream.File(name, FileMode.In), e, name);
    }
    ///close input stream
    public void close()
    {
        if(closeStream) input.close();
    }
    Stream input;
    Encoding enc;
    string name;
    bool closeStream;
    public this(Stream s, Encoding e, string name, bool closeStream = true)
    {
        input = s;
        enc = e;
        this.name = name;
        this.closeStream = closeStream;
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
			case NodeType.Statements:
                write('[');
                foreach(t; ((cast(Statements)tr).statements))
                {
                    to_s(t);
                    write(',');
                }
                write(']');
				break;
            case NodeType.ExpressionStatement:
                to_s((cast(ExpressionStatement)tr).expression);
                break;
            case NodeType.DefineVariable:
                DefineVariable dv = cast(DefineVariable)tr;
                writef("{NodeType:DefineVariable,");
                for(int i = 0;i < dv.variables.length; i++)
                {
                    write('[');
                    to_s(dv.variables[i]);
                    write(',');
                    to_s(dv.initExpressions[i]);
                    write(']');
                    if(i < dv.variables.length - 1)
                    {
                        write(',');
                    }
                }
                write('}');
                break;
            case NodeType.If:
                auto statementIf = cast(If)tr;
                writef("{NodeType:If,");
                write('[');
                to_s(statementIf.condition);
                write(',');
                to_s(statementIf.thenStatement);
                write(',');
                to_s(statementIf.elseStatement);
                write(']');
                write('}');
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
        global.global = &global;
        auto moyo = new Interpreter(&global);
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
    /**
    parse input stream
    */
    public void Parse()
    {
        auto tl = Lex();
        foreach(TokenList i; TokenListRange(tl))
        {
            writefln("\t{constant:%s, type:%s, name:%s},", i.constant, i.type, i.name);
        }
        auto exp = parseStatements(tl);//parseExpression(tl);//new Expression();
        to_s(exp);
        writeln();
        ERROR();
        //Tree tree = expression(tl, exp);
        global.initGlobal();
        global.global = &global;
        auto moyo = new Interpreter(&global);
        writeln();
        auto ret = moyo.runStatements(exp);
        writeln();
        writeln(ret);
    }
    Statement parseStatement(ref TokenList tl)
    {
        if(tl.type == TokenType.Iden)
        {
            switch(tl.reserved)
            {
                case Reserved.If:
                    return parseIf(tl);
                case Reserved.None:
                default:
                    if(tl.next && tl.next.type == TokenType.Iden)
                    {
                        //DefineVariable
                        return parseDefineVariable(tl);
                    }
            }
        }
        if(tl.type.isExpression())
        {
            return new ExpressionStatement(parseExpression(tl));
        }
        Error(new ParseError("Invalid Statement", tl));
        return null;
    }
    Statements parseStatements(ref TokenList tl)
    {
		Statements statements = new Statements();
		while(tl)
		{
            statements.statements.insertBack(parseStatement(tl));
		}
		return statements;
    }
    DefineVariable parseDefineVariable(ref TokenList tl)
    {
        DefineVariable dv = new DefineVariable(tl.name);
        tl = tl.next;
        while(tl)
        {
            if(tl.type != TokenType.Iden) break;
            mstring variablename = tl.name;
            if(tl)tl = tl.next;
            Expression initexp;
            if(tl.type == TokenType.Assign)
            {
                tl = tl.next;
                initexp = parseExpression(tl);
            }
            dv.add(variablename, initexp);
            if(tl.type == TokenType.Comma)
            {
                if(tl)tl = tl.next;
                continue;
            }
            
            break;
        }
        return dv;
    }
    If parseIf(ref TokenList tl)
    {
        auto statementIf = new If();
        tl = tl.next;
        statementIf.condition = parseExpression(tl);
        statementIf.thenStatement = parseStatement(tl);
        if(tl && tl.name == "else")
        {
            tl = tl.next;
            statementIf.elseStatement = parseStatement(tl);
        }
        return statementIf;
    }
    public Expression expression(ref TokenList tl)
    {
        if(!tl)
        {
            Error(new ParseError("Syntax Error(Expression) parser bug?"));
            return null;
        }//throw new ParseException("Syntax Error(Expression)", tl);
        Constant cons;
        Expression tree;
        switch(tl.type)
        {
            case TokenType.String:
            case TokenType.Number:
                cons = new Constant();
                cons.value = tl.constant;
                tree = cons;
                cons.valueType = tl.constant.Type;
                break;
            case TokenType.LeftParenthesis:
                auto tk = tl.next;
                tree = parseExpression(tk);
                tl = tk;
                break;
            case TokenType.Iden:
                return new Variable(tl.name);
                break;
            default:
                //Error(new ParseError("Syntax Error(Expression)", tl));
                return null;
        }
        return tree;
    }
    Expression parseExpression(ref TokenList tl)
    {
        Expression tree;
        Expression op1 = expression(tl);
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
            //Error(new ParseError("Syntax Error(Operator)", tl));
            return op1;
        }
        Expression bo = new BinaryOperator(op1, null, tl.type);
        if(expression2(tl, bo)) return bo;
        if(!tl) return bo;
        expression(tl, bo);
        while(tl && tl.next && tl.type.isOperator())//kimmo
        {
            auto bobo = cast(BinaryOperator)bo;
            if(tl.type.rank() >= bobo.type.rank && bobo.type.rank != AssignRank)
            {
                bobo = new BinaryOperator(null, null, tl.type);
                bobo.OP1 = bo;
                tree = bobo;
                expression(tl, tree);
                bo = tree;
            }
            else//右再帰 
            {
                auto bi = new BinaryOperator(op1, null, tl.type);
                bobo.OP2 = bi;
                expression(tl, bobo.OP2);
            }
        }
        tree = bo;
        return tree;
    }
    auto expression2(ref TokenList tl, ref Expression tr)
    {
        BinaryOperator bo = cast(BinaryOperator)tr;
        if(bo.type == TokenType.LeftParenthesis)
        {
            parseFunctionCall(tl, tr);
            return true;
        }
        return false;
    }
    auto parseFunctionCall(ref TokenList tl, ref Expression tr)
    {
        BinaryOperator bo = cast(BinaryOperator)tr;
        auto func = new FunctionArgs();
        bo.OP2 = func;
        tl = tl.next;
        while(tl !is null && tl.type != TokenType.RightParenthesis)
        {
            func.args.insertBack(parseExpression(tl));
            if(tl is null || tl.type == TokenType.RightParenthesis) break;
            if(tl)tl = tl.next;
        }
        if(tl)tl = tl.next;
        return func;
    }
    void expression(ref TokenList tl, ref Expression tr)
    {
        BinaryOperator bo = cast(BinaryOperator)tr;
        auto bino = bo;
        auto op = tl.type;
        tl = tl.next;
        Expression op1 = expression(tl);
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
            //   Error(new ParseError("Syntax Error(Operator): " ~ tl.type.to!string, tl));
            bo.OP2 = op1;
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
            tr = bo;
            return;
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
            expression(tl, bo.OP2);
            while(tl && tl.next && tl.type.isOperator())//kimmo
            {
                if(tl.type.rank() >= bo.type.rank && bo.type.rank != AssignRank)
                {
                    bo = new BinaryOperator(null, null, tl.type);
                    bo.OP1 = bino;
                    tr = bo;
                    expression(tl, tr);
                }
                else//右再帰 
                {
                    bi = new BinaryOperator(bo.OP2, null, tl.type);
                    bo.OP2 = bi;
                    expression(tl, bo.OP2);
                }
            }
        }
    }
    enum ParserStat
    {
        None,
        Iden,
        Number,
        String,
        EscapeString,
        InvalidChar,
    }
    Array!ParseError errors;
    void Error(ParseError pe)
    {
        errors.insertBack(pe);
    }
    /**
    lexical analyzer
    */
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
            t.linepos = linepos - length;
            t.position = position - length + 1;
            t.length = 1;
            t.type = tt;
            t.constant = constant;
        }
        void AddListIden(TokenType tt, int length, mstring iden)
        {
            auto t = new TokenList(iden);
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
        }
        void AddListString(TokenType tt, int length, mstring str)
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
            t.name = str;
            t.constant = MObject(str);
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
        bool isLast = false;
        wchar next()
        {
            wchar next;
            if(isWide)
            {
                next = input.getcw();
                if(next == wchar.init)isLast = true;
            }
            else
            {
                next = cast(wchar)input.getc();
                if(next == char.init)isLast = true;
            }
            position++;
            linepos++;
            return next;
        }
        while(true){
            inchar = next();
            switch(ps)
            {
                case ParserStat.None:
                    case_ParserStat_None:
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
                            wchar nextchar = next();
                            if(nextchar == '=')
                                AddList(TokenType.Equals);
                            else
                            {
                                AddList(TokenType.Assign);
                                inchar = nextchar;
                                goto case_ParserStat_None;
                            }
                            break;
                        case ',':
                            AddList(TokenType.Comma);
                            break;
                        case '\n':
                            line++;
                            linepos = -1;
                            break;
                        case '"':
                            ps = ParserStat.String;
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
                case ParserStat.EscapeString:
                    wchar esc;
                    switch(inchar)
                    {
                        case 't':
                            esc = '\t';
                            break;
                        case 'n':
                            esc = '\n';
                            break;
                        case 'r':
                            esc = '\r';
                            break;
                        case '"':
                            esc = '\"';
                            break;
                        default:
                            esc = inchar;
                            Error(new ParseError("Invalid escape char", line,position,1,linepos));
                            break;
                    }
                    ms.write(esc);
                    len++;
                    ps = ParserStat.String;
                    break;
                case ParserStat.String:
                    if(inchar != '"')
                    {
                        if(inchar == '\\')
                        {
                            ps = ParserStat.EscapeString;
                            continue;
                        }
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
                        AddListString(TokenType.String, len, wstr);
                        ps = ParserStat.None;
                        len = 0;
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
            if(isLast)break;
            //            write(inchar);
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