/**
 * Lexer for generation of transcript json from transcripts.
 */

import java.io.PrintStream;
import java.util.ArrayList;
import java.util.List;

%%

%class TranscriptLexer
%unicode
%line
%column
%standalone

%{
    // This is verbatim code for the TranscriptLexer class.
    public static class Utterance {
        public Utterance(String speaker, String timestamp) {
            this.speaker = speaker;
            this.timestamp = timestamp;
            this.utterance = null;
        }

        public String speaker;
        public String timestamp;
        public String utterance;
    };
    public static final String INDENT = "    ";

    public String title;
    public String date;
    public List<Utterance> interview = new ArrayList<Utterance>();

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
        out.printf("\"%s\"", value);
    }

    private void printObjectComma(PrintStream out) {
        out.println(",");
    }

    private void printJson(PrintStream out) {
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
                                    ": New utterance detected before old utterance completed");

                            currentUtterance = new Utterance(currentSpeaker, yytext().trim());
                            interview.add(currentUtterance);
                        }

    {Utterance}         {
                            if (yytext().trim().equals("END OF TRANSCRIPT")) {
                                yybegin(FINISHED);
                            } else if (currentUtterance.utterance != null) {
                                throw new IllegalStateException("Error at line " + yyline +
                                    ": Multiple utterances found for single utterance.");
                            } else {
                                String utterance = yytext().trim();
                                utterance = utterance.replace("\"", "\\\"");
                                utterance = utterance.replace("\\s\\s*", " ");
                                currentUtterance.utterance = utterance;
                            }
                        }

    <<EOF>>             {
                            printJson(System.out);
                            System.out.flush();
                            System.exit(0);
                        }

    .|\n                {
                            throw new IllegalStateException("No interview found at line " +
                                yyline + ", column " + yycolumn);
                        }
}

<FINISHED> {
    .|\n                { /* Ignore everything, we are finished. */ }
    <<EOF>>             {
                            printJson(System.out);
                            System.out.flush();
                            System.exit(0);
                        }
}
