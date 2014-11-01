module moyo.parser;
import moyo.tree;
import moyo.mobject;
import moyo.interpreter;
import moyo.stdio;
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
bool isUnaryOperator(TokenType tt)
{
    return isUOP[tt];
}
bool isExpression(TokenType tt)
{
    return tt.isOperator() || tt <= TokenType.String;
}
Reserved[mstring] reservedTable;
//先頭が大文字なのは予約語と衝突を避けるため
enum Reserved : byte
{
    None,
    If,
    Else,
    For,
    Break,
    Continue,
    Return,
    Class,
    Public,
    Protected,
    Private,
    New,
}
class TokenList
{
    static this()
    {
        reservedTable = [
            "if": Reserved.If,
            "else": Reserved.Else,
            "for": Reserved.For,
            "break": Reserved.Break,
            "continue": Reserved.Continue,
            "return": Reserved.Return,
            "class": Reserved.Class,
            "public": Reserved.Public,
            "protected": Reserved.Protected,
            "private": Reserved.Private,
            "new": Reserved.New,
        ];
        reservedTable.rehash();
        end = new TokenList();
        end.next = end;
    }
    TokenType type;
    TokenList next;
    int position;
    int length;
    int line;
    int linepos;
    MObject constant;
    mstring name;
    @property bool isEnd()
    {
        return this == end;
    }
    this()
    {
        this.next = end;
    }
    this(mstring name)
    {
        this();
        assert(this.next !is null);
        this.name = name;
        auto res = (name in reservedTable);
        reserved = res ? *res : Reserved.None;
    }
    Reserved reserved;
    static TokenList end;
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
        return __front.isEnd;
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
    ///そのうち実装する
    this(string message, Tree tree)
    {
        if(!tree || !tree.token)
        {
            this(message);
            return;
        }
        this(message, tree.token);
    }
    this(string message, TokenList tl)
    {
        msg = message;
        if(tl.isEnd) return;
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
    //面倒だしやめた
    switch(type)
    {
        case TokenType.Dot:
            return 1;
        case TokenType.LeftParenthesis:
            return 2;
        case TokenType.Mul:
        case TokenType.Div:
        case TokenType.Mod:
            return 5;
        case TokenType.Plus:
        case TokenType.Minus:
            return 6;
        case TokenType.Less:
        case TokenType.Greater:
        case TokenType.LessOrEqual:
        case TokenType.GreaterOrEqual:
            return 8;
        case TokenType.Equals:
        case TokenType.NotEquals:
            return 9;
        case TokenType.Assign:
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
    ///鳥栖
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
                writef("],valueType:%s}", (cast(BinaryOperator)tr).valueType);
                break;
            case NodeType.UnaryOperator:
                write("{type:");
                write((cast(UnaryOperator)tr).type);
                write(',');
                to_s((cast(UnaryOperator)tr).OP);
                writef(",valueType:%s}", (cast(UnaryOperator)tr).valueType);
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
                writef("{NodeType:DefineVariable,define:");
                for(int i = 0;i < dv.variables.length; i++)
                {
                    write('[');
                    to_s(dv.variables[i]);
                    write(',');
                    to_s(dv.initExpressions[i]);
                    write(']');
                    write(',');
                }
                writef("valueType:%s", dv.valueType);
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
            case NodeType.For:
                auto statementFor = cast(For)tr;
                writef("{NodeType:For,");
                write('[');
                to_s(statementFor.initStatement);
                write(',');
                to_s(statementFor.condition);
                write(',');
                to_s(statementFor.loop);
                write(',');
                to_s(statementFor.statement);
                write(']');
                write('}');
                break;
            case NodeType.DefineFunction:
                auto df = cast(DefineFunction)tr;
                writef("{NodeType:DefineFunction,");
                write('[');
                write(df.type);
                write(',');
                write(df.name);
                write(',');
                foreach(i; df.args)
                {
                    write('[');
                    write(i.type);
                    write(',');
                    write(i.name);
                    write(']');
                    write(',');
                }
                to_s(df.statement);
                write(']');
                writef(",valueType:%s}", df.valueType);
                break;
            case NodeType.Return:
                writef("{NodeType:Return,");
                to_s((cast(Return)tr).expression);
                write('}');
                break;
            case NodeType.DefineClass:
                auto dc = cast(DefineClass)tr;
                writef("{NodeType:DefineClass,name:%s,variables:[", dc.name);
                foreach(i; dc.variables)
                {
                    write('[');
                    write(i.access, ',');
                    to_s(i.value);
                    write(']');
                    write(',');
                }
                write("],functions:[");
                foreach(i; dc.functions)
                {
                    write('[');
                    write(i.access, ',');
                    to_s(i.value);
                    write(']');
                    write(',');
                }
                write("]");
                write('}');
                break;
            default:

        }
        stdout.flush();
    }
    Variables global;
    //unittest用
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
        //auto exp = parseStatements(tl);//parseExpression(tl);//new Expression();
        auto roots = parseGlobal(tl);
        foreach(exp; roots)
        {
            to_s(exp);
            write(',');
        }
        writeln();
        StaticVariable sv = StaticVariable();
        sv.initGlobal();
        StaticVariable svt = StaticVariable();
        svt.initTypeGlobal();
        global.initGlobal();
        global.global = &global;
        foreach(exp; roots)
        {
            if(exp.Type == NodeType.DefineClass)
            {
                auto dc = cast(DefineClass)exp;
                dc.createClassInfo();//とりあえずまだ継承は未実装
                sv.define(dc.name, ValueType(ObjectType.Class, dc.classInfo));
            }
        }
        foreach(exp; roots)
        {
            if(exp.Type == NodeType.DefineFunction)
            {
                auto func = cast(DefineFunction)exp;
                typeInference(func, sv, svt);
            }
            else
            if(exp.Type == NodeType.DefineClass)
            {
                auto dc = cast(DefineClass)exp;
                auto classInfo = dc.classInfo;
                svt.define(dc.name, ValueType(ObjectType.ClassInstance, classInfo.instance));
                foreach(mem; dc.variables)
                {
                    DefineVariable dv = mem.value;
                    foreach(var; dv.variables)
                        classInfo.instance.addMember(var.name, sv.nameToType(dv.typeName, svt));
                }
                foreach(fun; dc.functions)
                {
                    DefineFunction df = fun.value;
                }
                //とりあえず
                global.define(dc.name, MObject(new MClass(classInfo)));
            }
        }
        foreach(exp; roots)
        {
            typeInference(exp, sv, svt);
        }
        writeln("===TypeInference===");
        foreach(exp; roots)
        {
            to_s(exp);
            write(',');
        }
        writeln();
        ERROR();
        //Tree tree = expression(tl, exp);
        auto moyo = new Interpreter(&global);
        writeln();
        MObject ret;
        foreach(exp; roots)
        {
            if(exp.Type != NodeType.DefineFunction)
                moyo.runStatement(cast(Statement)exp, ret);
        }
        writeln();
        writeln(ret);
    }
    void typeInference(DefineFunction func, ref StaticVariable variable, ref StaticVariable type)
    {
        func.valueType = variable.nameToType(func.type, type);
        auto sts = cast(Statements)func.statement;
        auto fc = new FunctionClassInfo();
        foreach(ref i; func.args)
        {
            auto ftype = variable.nameToType(i.type, type);
            fc.args.insertBack(ftype);
            sts.variables.define(i.name, ftype);
        }
        fc.retType = func.valueType;
        variable.define(func.name, ValueType(ObjectType.Function, fc));
        auto munc = MObject(new MFunction(func));
        global.define(func.name, munc);
        variable.define(func.name, ValueType(ObjectType.Function));
    }
    ///文の型推論を行います。
    ValueType typeInference(Tree statement, ref StaticVariable variable, ref StaticVariable type)
    {
        switch(statement.Type)
        {
            case NodeType.DefineVariable:
                DefineVariable dv = cast(DefineVariable)statement;
                dv.valueType = typeInference(dv.initExpressions[0], variable, type);
                variable.define(dv.variables[0].name, dv.valueType);
                for(int i = 1;i < dv.variables.length;i++)
                {
                    auto vt = typeInference(dv.initExpressions[i], variable, type);
                    if(vt != dv.valueType) Error(new ParseError("型が違う"));
                    variable.define(dv.variables[i].name, dv.valueType);
                }
                return dv.valueType;
            case NodeType.ExpressionStatement:
                ExpressionStatement es = cast(ExpressionStatement)statement;
                return typeInference(es.expression, variable, type);
            case NodeType.Statements:
                auto ss = cast(Statements)statement;
                foreach(s; ss.statements)
                {
                    typeInference(s, ss.variables, type);
                }
                return ValueType.errorType;
            case NodeType.Return:
                return typeInference((cast(Return)statement).expression, variable, type);
            case NodeType.DefineFunction:
                auto df = cast(DefineFunction)statement;
                typeInference(df.statement, variable, type);
                return ValueType.errorType;
            default:
                return ValueType.errorType;
        }
    }
    ///式の型推論を行います。
    ///ついでに定数式展開(デバッグの支障になるからまだやらない)
    ValueType typeInference(Expression exp, ref StaticVariable variable, ref StaticVariable type)
    {
        switch(exp.Type)
        {
            case NodeType.BinaryOperator:
                BinaryOperator bo = cast(BinaryOperator)exp;
                ValueType op1 = typeInference(bo.OP1, variable, type);
                if(bo.type == TokenType.Dot)
                {
                    if(bo.OP2.Type != NodeType.Variable)
                    {
                        Error(new ParseError("変数じゃない" ~ ((cast(Variable)bo.OP1).name.to!string)));
                        return ValueType.errorType;
                    }
                    mstring name = (cast(Variable)bo.OP2).name;
                    try
                    {
                        return bo.valueType = op1.opDot(name);
                    }
                    catch(VariableUndefinedException VUE)
                    {
                        Error(VUE.msg, bo);
                    }
                }
                ValueType op2 = typeInference(bo.OP2, variable, type);
                if(bo.type == TokenType.LeftParenthesis)
                {
                    //関数呼び出し
                    //返り血が分っているのであればそれを返す、分かっていないなら今から解析
                    if(op1.type == ObjectType.Function)
                    {
                        return bo.valueType = (cast(FunctionClassInfo)op1.classInfo).retType;
                    }
                    Error(new ParseError("Function!?", bo));
                    return ValueType.errorType;
                }
                if(bo.type == TokenType.Assign)
                {
                    if(bo.OP1.Type != NodeType.Variable)
                    {
                        auto dotbo = cast(BinaryOperator)bo.OP1;
                        if(dotbo && dotbo.type == TokenType.Dot)
                        {
                            //bo.valueType = 
                            auto typevar = typeInference(dotbo, variable, type);
                            bo.valueType = dotbo.valueType;
                            if(bo.valueType.isErrorType)
                            {
                                Error(new ParseError("無効な代入", bo));
                                return ValueType.errorType;
                            }
                            if(typevar != op2)
                            {
                                Error(new ParseError("変数の型が違います", bo));
                                return typevar;
                            }
                            return typevar;//dotbo.valueType;
                        }
                        Error(new ParseError("無効な代入", bo));
                        return ValueType.errorType;
                    }
                    auto ptr = variable.getptr((cast(Variable)bo.OP1).name);
                    if(!ptr)
                    {
                        Error(new ParseError("存在しない変数" ~ (cast(Variable)bo.OP1).name.to!string, bo));
                        return ValueType.errorType;
                    }
                    if((*ptr).type != op2.type)
                    {
                        Error(new ParseError("変数の型が違います" ~ ((cast(Variable)bo.OP1).name.to!string), bo));
                        return ValueType.errorType;
                    }
                }
                return bo.valueType = AutoOperator(op1, op2, bo.type);
            case NodeType.UnaryOperator:
                auto uo = cast(UnaryOperator)exp;
                if(uo.type == TokenType.New)
                {
                    auto callctor = cast(BinaryOperator)uo.OP;
                    //uo.OPがBinaryOperatorであり、それが関数呼び出しであり、それのOP1が変数である場合
                    if(callctor && callctor.type == TokenType.FuncCall)
                    {
                        auto var = cast(Variable)callctor.OP1;
                        auto args = cast(FunctionArgs)callctor.OP2;
                        if(var && args)
                        {
                            //TODO: コンストラクタ引数の型のチェックは未実装
                            return callctor.valueType = variable.nameToType(var.name, type);
                        }
                    }
                    Error("コンストラクタ呼び出しが不正です。", uo);
                    return ValueType.errorType;
                }
                return ValueType.errorType;
            case NodeType.Constant:
                return exp.valueType;
            case NodeType.Variable:
                auto v = cast(Variable)exp;
                auto var = variable.getptr(v.name);
                if(!var) 
                {
                    Error("変数が定義されていません。" ~ v.name.to!string, v);
                    return ValueType.errorType;
                }
                return v.valueType = *var;
            case NodeType.FunctionArgs:
                auto fa = cast(FunctionArgs)exp;
                foreach(f; fa.args)
                {
                    typeInference(f, variable, type);
                }
                return ValueType.errorType;
            default:
                return ValueType.errorType;
        }
    }
    Array!Tree parseGlobal(ref TokenList tl)
    {
		Array!Tree nodes;
		while(!tl.isEnd)
		{
            if(tl.type == TokenType.Iden)
            {
                switch(tl.reserved)
                {
                    case Reserved.None:
                        if(tl.next && tl.next.type == TokenType.Iden &&
                           tl.next.next && tl.next.next.type == TokenType.LeftParenthesis)//関数定義 type-name func-name()
                        {
                            nodes.insertBack(parseDefineFunction(tl));
                            continue;
                        }
                        break;
                    case Reserved.Class:
                        nodes.insertBack(parseDefileClass(tl));
                        continue;
                    default:
                }
            }
            nodes.insertBack(parseStatement(tl));
            if(tl && tl.type == TokenType.BlockEnd) 
            {
                tl = tl.next;
                Error(new ParseError("予期せぬ'}'", tl));
                break;
            }
        }
		return nodes;
    }
    bool isTypeName(TokenList tl)
    {
        if(tl.type != TokenType.Iden) return false;
        tl = tl.next;//iden
        //gonyo
        return true;
    }
    DefineClass parseDefileClass(ref TokenList tl)
    {
        auto dc = new DefineClass(tl);
        tl = tl.next;//name
        dc.name = tl.name;
        tl = tl.next;
        if(tl.type != TokenType.BlockStart)
        {
            Error(new ParseError("class定義は{で始まる必要があります。}", dc));
        }
        tl = tl.next;
        Reserved access = Reserved.None;
        while(!tl.isEnd)
        {
            if(tl.type == TokenType.Iden)
            {
                switch(tl.reserved)
                {
                    case Reserved.Public:
                    case Reserved.Protected:
                    case Reserved.Private:
                        if(access != Reserved.None)
                        {
                            Error("public, protected, privateを複数指定する事は出来ません。", tl);
                        }
                        access = tl.reserved;
                        tl = tl.next;
                        if(tl.type != TokenType.Iden)
                        {
                            Error("型名は識別子で始まる必要があります。", tl);
                            continue;
                        }
                        if(tl.reserved >= Reserved.Public && tl.reserved <= Reserved.Private) 
                        {
                            continue;
                        }
                        goto default;
                    default:
                        if(tl.next.type != TokenType.Iden)
                        {
                            Error("不正な宣言", tl.next);
                        }
                        if(access == Reserved.None)
                        {
                            access = Reserved.Public;
                        }
                        auto tnn = tl.next.next;//not TNN
                        writeln(tl.type,",",tl.next.type,",",tnn.type);
                        if(tnn.type == TokenType.LeftParenthesis)
                        {
                            //関数
                            dc.add(parseDefineFunction(tl), access.toAccess);
                        }
                        else 
                        {
                            dc.add(parseDefineVariable(tl), access.toAccess);
                        }
                        access = Reserved.None;
                        continue;
                }
            }
            tl = tl.next;
        }
        return dc;
    }
    //ただしstatic/public/privateは無いものとする
    DefineFunction parseDefineFunction(ref TokenList tl)
    {
        auto df = new DefineFunction(tl);
        df.type = tl.name;
        tl = tl.next;
        df.name = tl.name;
        tl = tl.next;//(
        tl = tl.next;//type-name1
        while(tl && tl.type != TokenType.RightParenthesis)
        {
            if(tl.next)
            {
                df.add(tl.name, tl.next.name);
                tl = tl.next;
                if(tl.next.type != TokenType.RightParenthesis)tl = tl.next;
            }
            tl = tl.next;
        }
        if(tl)tl = tl.next;
        df.statement = parseStatement(tl);
        return df;
    }
    Return parseReturn(ref TokenList tl)
    {
        auto ret = new Return(tl);
        tl = tl.next;
        ret.expression = parseExpression(tl);
        return ret;
    }
    Statement parseStatement(ref TokenList tl)
    {
        if(tl.type == TokenType.BlockStart)
        {
            tl = tl.next;
            return parseStatements(tl);
        }
        if(tl.type == TokenType.Iden)
        {
            switch(tl.reserved)
            {
                case Reserved.If:
                    return parseIf(tl);
                case Reserved.For:
                    return parseFor(tl);
                case Reserved.Break:
                    tl = tl.next;
                    return new Break(tl);
                case Reserved.Continue:
                    tl = tl.next;
                    return new Continue(tl);
                case Reserved.Return:
                    return parseReturn(tl);
                case Reserved.None:
                default:
                    if(tl.type == TokenType.Iden && tl.next && tl.next.type == TokenType.Iden)
                    {
                        //DefineVariable
                        return parseDefineVariable(tl);
                    }
            }
        }
        if(tl.type.isExpression())
        {
            return new ExpressionStatement(parseExpression(tl), tl);
        }
        tl = tl.next;
        Error(new ParseError("Invalid Statement", tl));
        return null;
    }
    Statements parseStatements(ref TokenList tl)
    {
		Statements statements = new Statements(tl);
        if(tl && tl.type == TokenType.BlockEnd) 
        {
            tl = tl.next;
            return statements;
        }
		while(!tl.isEnd)
		{
            statements.statements.insertBack(parseStatement(tl));
            if(tl && tl.type == TokenType.BlockEnd) 
            {
                tl = tl.next;
                break;
            }
        }
		return statements;
    }
    DefineVariable parseDefineVariable(ref TokenList tl)
    {
        DefineVariable dv = new DefineVariable(tl.name, tl);
        tl = tl.next;
        while(!tl.isEnd)
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
            dv.add(variablename, initexp, tl);
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
        auto statementIf = new If(tl);
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
    For parseFor(ref TokenList tl)
    {
        auto statementFor = new For(tl);
        tl = tl.next;
        if(tl.type != TokenType.LeftParenthesis)
        {
            Error(new ParseError("forの後には括弧が必要です。", tl));
        }
        tl = tl.next;
        //空白文だったら飛ばす
        Statement _1 = tl.type == TokenType.Semicolon ? null : parseStatement(tl);
        
        if(_1.Type != NodeType.DefineVariable && _1.Type != NodeType.ExpressionStatement)
        {
            Error(new ParseError("forの文には変数宣言か式か空白である必要があります。", tl));
        }
        if(tl.type != TokenType.Semicolon)
        {
            Error(new ParseError("forの文の後には;を置いてください。", tl));
        }
        else
        tl = tl.next;
        Expression _2 =  tl.type == TokenType.Semicolon ? null : parseExpression(tl);
        if(tl.type != TokenType.Semicolon)
        {
            Error(new ParseError("forの文の後には;を置いてください。", tl));
        }
        else
            tl = tl.next;
        Expression _3 =  tl.type == TokenType.RightParenthesis ? null : parseExpression(tl);
        if(tl.type != TokenType.RightParenthesis)
        {
            Error(new ParseError("forの文の後には括弧が必要です。", tl));
        }
        else
            tl = tl.next;
        statementFor.initStatement = _1;
        statementFor.condition = _2;
        statementFor.loop = _3;
        statementFor.statement = parseStatement(tl);
        return statementFor;
    }
    public Expression expression(ref TokenList tl)
    {
        if(tl.isEnd)
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
                cons = new Constant(tl);
                cons.value = tl.constant;
                tree = cons;
                cons.valueType = ValueType(tl.constant.Type);
                break;
            case TokenType.LeftParenthesis:
                auto tk = tl.next;
                tree = parseExpression(tk);
                tl = tk;
                break;
            case TokenType.Iden:
                return new Variable(tl.name, tl);
                break;
            default:
                //Error(new ParseError("Syntax Error(Expression)", tl));
                return null;
        }
        return tree;
    }
    //lambda
    Expression nonOpExpression(ref TokenList tl, Expression op1)
    {
         return op1;
    }
    Expression parseExpression(ref TokenList tl)
    {
        Expression tree;
        if(tl.type.isUnaryOperator || (tl.reserved == Reserved.New))
        {
            if(tl.reserved == Reserved.New)
                tl.type = TokenType.New;
            auto type = tl;
            tl = tl.next;
            return new UnaryOperator(parseExpression(tl), type.type, type);
        }
        Expression op1 = expression(tl);
        if(tl.isEnd) return op1;
        tl = tl.next;
        if(tl.isEnd) return op1;
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
        Expression bo = new BinaryOperator(op1, null, tl.type, tl);
        if(expression2(tl, bo)) return bo;
        if(tl.isEnd) return bo;
        expression(tl, bo);
        while(tl && tl.next && tl.type.isOperator())//kimmo
        {
            auto bobo = cast(BinaryOperator)bo;
            if(tl.type.rank() >= bobo.type.rank && bobo.type.rank != AssignRank)
            {
                bobo = new BinaryOperator(null, null, tl.type, tl);
                bobo.OP1 = bo;
                tree = bobo;
                Expression exp = bobo;
                if(expression2(tl, exp))
                {
                    bo = exp;
                    continue;
                }
                expression(tl, tree);
                bo = tree;
            }
            else//右再帰 
            {
                Expression exp = bobo;
                if(bobo.type == TokenType.LeftParenthesis)
                {
                    bobo = new BinaryOperator(null, null, tl.type, tl);
                    bobo.OP1 = bo;
                    tree = bobo;
                    expression(tl, tree);
                    bo = tree;
                    continue;
                }
                auto bi = new BinaryOperator(op1, null, tl.type, tl);
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
        auto func = new FunctionArgs(tl);
        bo.OP2 = func;
        tl = tl.next;
        while(!tl.isEnd && tl.type != TokenType.RightParenthesis)
        {
            func.args.insertBack(parseExpression(tl));
            if(tl.isEnd || tl.type == TokenType.RightParenthesis) break;
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
        if(tl.type.isUnaryOperator || (tl.reserved == Reserved.New))
        {
            if(tl.reserved == Reserved.New)
                tl.type = TokenType.New;
            auto type = tl;
            tl = tl.next;
            (cast(BinaryOperator)tr).OP2 = new UnaryOperator(parseExpression(tl), type.type, type);
            return;
        }
        Expression op1 = expression(tl);
        if(tl.isEnd) return;
        tl = tl.next;
        if(tl.isEnd)
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
        {/*
            tr = bo;
            bo.OP2 = op1;*/
            return;
        }
        //大きければ左再帰する
        if(tl.type.rank() >= bo.type.rank && bo.type.rank != AssignRank)
        {
            tr = bo;
            bo.OP2 = op1;
            return;
            // bo.OP1 = ;
            bo = new BinaryOperator(null, null, tl.type, tl);
            bo.OP1 = bino;
            tr = bo;
            expression(tl, tr);
        }
        else//右再帰 
        {
            auto bi = new BinaryOperator(op1, null, tl.type, tl);
            bo.OP2 = bi;
            expression(tl, bo.OP2);
            while(tl && tl.next && tl.type.isOperator())//kimmo
            {
                if(tl.type.rank() >= bo.type.rank && bo.type.rank != AssignRank)
                {
                    bo = new BinaryOperator(null, null, tl.type, tl);
                    bo.OP1 = bino;
                    tr = bo;
                    expression(tl, tr);
                }
                else//右再帰 
                {
                    bi = new BinaryOperator(bo.OP2, null, tl.type, tl);
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
    void Error(string msg, TokenList tl)
    {
        Error(new ParseError(msg, tl));
    }
    void Error(string msg)
    {
        Error(new ParseError(msg));
    }
    void Error(string msg, Tree tree)
    {
        Error(new ParseError(msg, tree));
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
        int line = 1;
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
            t.line = line;
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
            t.line = line;
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
            t.line = line;
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
                                if(nextchar == '>')
                                {
                                    AddList(TokenType.Lambda);
                                    break;
                                }
                                AddList(TokenType.Assign);
                                inchar = nextchar;
                                goto case_ParserStat_None;
                            }
                            break;
                        case '<':
                            wchar nextchar = next();
                            if(nextchar == '=')
                                AddList(TokenType.LessOrEqual);
                            else
                            {
                                AddList(TokenType.Less);
                                inchar = nextchar;
                                goto case_ParserStat_None;
                            }
                            break;
                        case '>':
                            wchar nextchar = next();
                            if(nextchar == '=')
                                AddList(TokenType.Greater);
                            else
                            {
                                AddList(TokenType.GreaterOrEqual);
                                inchar = nextchar;
                                goto case_ParserStat_None;
                            }
                            break;
                        case '!':
                            wchar nextchar = next();
                            if(nextchar == '=')
                                AddList(TokenType.NotEquals);
                            else
                            {
                                //AddList(TokenType.Assign);
                                //inchar = nextchar;
                                //goto case_ParserStat_None;
                            }
                            break;
                        case '.':
                            AddList(TokenType.Dot);
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
                        case '{':
                            AddList(TokenType.BlockStart);
                            break;
                        case '}':
                            AddList(TokenType.BlockEnd);
                            break;
                        case ';':
                            AddList(TokenType.Semicolon);
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
            if(c == '\n' || c == '\r')
            {
                getc();
                break;
            }
            if(c == wchar.init || s.position == 0)
            {
                break;
            }
        }
        return cast(string)s.readLine;
    }
}