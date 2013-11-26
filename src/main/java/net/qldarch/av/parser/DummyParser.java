package net.qldarch.av.parser;

import org.apache.commons.io.IOUtils;

import java.io.InputStream;
import java.io.IOException;
import java.io.PrintStream;
import java.io.Reader;

public class DummyParser implements ParserToJSON {
    private final InputStream is;
    private final Reader r;

    public DummyParser(InputStream is) {
        this.is = is;
        this.r = null;
    }

    public DummyParser(Reader r) {
        this.is = null;
        this.r = r;
    }

    public ParserToJSON parse() throws IOException {
        return this; // Nop
    }

    public void printJson(PrintStream out) throws IOException {
        if (this.is != null) {
            IOUtils.copy(is, out);
        } if (this.r != null) {
            IOUtils.copy(r, out);
        } else {
            throw new IllegalStateException("No Input to DummyParser");
        }
    }

    public String getTitle() {
        return "Unparsed JSON";
    }
}
