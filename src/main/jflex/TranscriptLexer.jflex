/**
 * Lexer for generation of transcript json from transcripts.
 */
package net.qldarch.av.parser;

import java.io.PrintStream;
import java.util.ArrayList;
import java.util.List;

%%

%class TranscriptParser
%public
%unicode
%line
%column
%function parse
%type TranscriptParser

%{
    // This is verbatim code for the TranscriptLexer class.
    public static class Utterance {
        public Utterance(String speaker, String timestamp) {
            this.speaker = speaker;
            this.timestamp = timestamp;
            this.utterance = null;
        }

        public void appendUtterance(String utterance) {
            if (this.utterance == null) {
                this.utterance = utterance;
            } else {
                this.utterance = this.utterance + " " + utterance;
            }
        }

        private String speaker;
        private String timestamp;
        private String utterance;

        public String getSpeaker() { return speaker; }
        public String getTimestamp() { return timestamp; }
        public String getUtterance() { return utterance; }
    };

    private static final String INDENT = "    ";

    private String title;
    private String date;
    private List<Utterance> interview = new ArrayList<Utterance>();

    public String getTitle() { return title; }
    public String getDate() { return date; }
    public List<Utterance> getInterview() { return interview; }

    private String currentSpeaker = null;
    private Utterance currentUtterance = null;

    private void printField(PrintStream out, int indent, String label, String value) {
        printIndent(out, indent);
        printFieldLabel(out, label);
        printFieldValue(out, value);
    }

    private void printFieldC(PrintStream out, int indent, String label, String value) {
        printField(out, indent, label, value);
        printObjectComma(out);
    }

    private void printIndent(PrintStream out, int indent) {
        for (int i = 0; i < indent; i++) out.print(INDENT);
    }

    private void printFieldLabel(PrintStream out, String label) {
        out.printf("\"%s\": ", label);
    }

    private void printFieldValue(PrintStream out, String value) {
        out.printf("\"%s\"", cleanString(value));
    }

    private void printObjectComma(PrintStream out) {
        out.println(",");
    }

    private String cleanString(String value) {
        return value.replaceAll("\ufeff", "").replaceAll("\t\n\r\f", " ");
    }

    public void printJson(PrintStream out) {
        out.println("{");
        printFieldC(out, 1, "title", title);
        printFieldC(out, 1, "date", date);
        printIndent(out, 1);
        printFieldLabel(out, "exchanges");
        out.println("[");
        boolean isFirst = true;
        for (Utterance utterance : interview) {
            if (isFirst) {
                isFirst = false;
            } else {
                printObjectComma(out);
            }
            printIndent(out, 2);
            out.println("{");
            printFieldC(out, 3, "speaker", utterance.speaker);
            printFieldC(out, 3, "time", utterance.timestamp);
            printField(out, 3, "transcript", utterance.utterance);
            out.println("");
            printIndent(out, 2);
            out.print("}");
        }
        out.println("");
        printIndent(out, 1);
        out.println("]");
        out.println("}");
    }
%}

LineTerminator  = \r|\n|\r\n
Whitespace      = [ \t\f]
Initials        = [:letter:][:letter:]
NotWS           = [^ \r\n\t\f]
LineContents    = [^\r\n]
StartUtterance  = [^ \r\n\t\f0-9]
EndUtterance    = {NotWS}
Utterance       = {StartUtterance}|{StartUtterance}{LineContents}*{EndUtterance}
Timestamp = [:digit:][:digit:]":"[:digit:][:digit:]":"[:digit:][:digit:]

%state DATE
%state INTERVIEW
%state FINISHED

%%

<YYINITIAL> {
    {Whitespace}        { /* Ignore whitespace */ }
    {LineTerminator}    { /* Ignore line endings */ }
    {LineContents}+     {
                            yybegin(DATE);
                            title = yytext();
                        }
}

<DATE> {
    {Whitespace}        { /* Ignore whitespace */ }
    {LineTerminator}    { /* Ignore line endings */ }
    {LineContents}+     {
                            yybegin(INTERVIEW);
                            date = yytext();
                        }
}
    
<INTERVIEW> {
    {Whitespace}        { /* Ignore whitespace */ }
    {LineTerminator}    { /* Ignore line endings */ }

    {Initials}          {
                            currentSpeaker = yytext();
                        }

    {Timestamp}         {
                            if (currentSpeaker == null)
                                throw new IllegalStateException("Error at line " + yyline +
                                    ": Utterance without current speaker");

                            if (currentUtterance != null && currentUtterance.utterance == null)
                                throw new IllegalStateException("Error at line " + yyline +
                                    "(" + yytext() + ")" +
                                    ": New utterance detected before old utterance completed");

                            currentUtterance = new Utterance(currentSpeaker, yytext().trim());
                            interview.add(currentUtterance);
                        }

    {Utterance}         {
                            if (yytext().trim().equals("END OF TRANSCRIPT")) {
                                yybegin(FINISHED);
                            } else {
                                String utterance = yytext().trim();
                                utterance = utterance.replace("\"", "\\\"");
                                utterance = utterance.replace("\\s\\s*", " ");
                                currentUtterance.appendUtterance(utterance);
                            }
                        }

    <<EOF>>             {
                            return this;
                        }

    .|\n                {
                            throw new IllegalStateException("No interview found at line " +
                                yyline + ", column " + yycolumn);
                        }
}

<FINISHED> {
    .|\n                {
                            yyclose();
                            return this;
                        }

    <<EOF>>             {
                            return this;
                        }
}
