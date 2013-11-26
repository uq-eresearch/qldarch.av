package net.qldarch.av.parser;

import java.io.IOException;
import java.io.PrintStream;

public interface ParserToJSON {
    public ParserToJSON parse() throws IOException;
    public void printJson(PrintStream out) throws IOException;

    public String getTitle();
}
