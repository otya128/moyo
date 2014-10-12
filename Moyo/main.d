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