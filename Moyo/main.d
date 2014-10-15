import std.stdio, std.stream;
import moyo.tree;
import moyo.parser;

 int main(string[] argv)
{
    writeln("Hello D-World!");
    while(true)
    {
    string line = readln();
    auto ms = new MemoryStream();
    ms.position = 0;
    ms.write(line);
    ms.position = 4;//????
    auto parser = new Parser(ms,Encoding.ASCII);
    try
    {
        parser.Parse();
    }
    catch(ParseException pe)
    {
        writeln(pe.msg);
    }
    ms.close();
    }
    writeln("End D-World...");
    readln();
    return 0;
}

unittest
{
    void test(string val, int result)
    {
        auto ms = new MemoryStream();
        ms.write(val);
        ms.position = 4;//????
        auto parser = new Parser(ms,Encoding.ASCII);
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
            ms.write(val);
            ms.position = 4;//????
            auto parser = new Parser(ms,Encoding.ASCII);
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
    Eval("2+3*4+2") = 16;
    Eval("2+3*4*5+6*7+8") = 112;
    Eval("2+3*4*5") = 62;
    writeln("Test");
}