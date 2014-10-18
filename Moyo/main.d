import std.stdio, std.stream;
import moyo.tree;
import moyo.parser;
import moyo.interpreter;

 int main(string[] argv)
{
    writeln("Hello D-World!");
    while(true)
    {
        string line = readln();
        auto ms = new MemoryStream();
        ms.writeString(line);
        ms.position = 0;
        try
        {
            auto parser = Parser.fromFile("input.txt", Encoding.ASCII);//new Parser(ms,Encoding.ASCII, "stdin");
            scope(exit)
            {
                parser.close();
            }
            parser.Parse();
        }
        catch(ParseException pe)
        {
            writeln(pe.msg);
        }
        catch(RuntimeException re)
        {
            writeln(re);
        }
        catch(Exception e)
        {
            writeln(e);
        }
        ms.close();
    }
    writeln("End D-World...");
    readln();
    return 0;
}

import moyo.mobject;
import std.container;
///return last arg
MObject testFunc(argsType args)
{
    return args[args.length - 1];
}

void test(string val, int result)
{
    auto ms = new MemoryStream();
    ms.writeString(val);
    ms.position = 0;
    auto parser = new Parser(ms,Encoding.ASCII, "unittest");
    try
    {
        assert(parser.ParseAndEval().value.Int32 == result);
    }
    catch(Exception e)
    {
        assert(false, e.toString());
    }
    ms.close();
}
unittest
{
    auto testFunction = MObject(new NativeFunction(&testFunc, "test"));
    struct Eval
    {
        string val;
        this(string val)
        {
            this.val = val;
        }
        bool opAssign(int result)
        {
            auto ms = new MemoryStream();
            ms.writeString(val);
            ms.position = 0;
            auto parser = new Parser(ms,Encoding.ASCII, "unittest");
            parser.global.define("test", testFunction);
            try
            {
                assert(parser.ParseAndEval().value.Int32 == result);
            }
            catch(Exception e)
            {
                assert(false, e.toString());
            }
            ms.close();
            return false;
        }
    }
    test("1+1", 2);//1+1は2
    test("2*3+2", 8);//2*3+2は8
    test("2*3+2+1", 9);//2*3+2+1は9
    Eval("2+3*4+2") = 2+3*4+2;
    Eval("2+3*4*5+6*7+8") = 2+3*4*5+6*7+8;
    Eval("2+3*4*5") = 2+3*4*5;
    Eval("(2+3)*4*5") = (2+3)*4*5;
    Eval("(1)+(2)") = (1)+(2);
    Test!"2+(3+4)*5"();
    Test!"2+20/5*3"();
    Eval("test(2+5)") = 2+5;
    Eval("test(2+5, test(2, 3+5))") = 3+5;
    Test!"2-3*4-5"();
    writeln("Test");
}
//D言語の式の評価結果と同じか検証
void Test(const char[] V)()
{
    mixin("test(\""~V~"\", "~V~");");
}
