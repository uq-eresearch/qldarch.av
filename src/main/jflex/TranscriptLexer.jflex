/**
 * Lexer for generation of transcript json from transcripts.
 */
package net.qldarch.av.parser;

import java.io.PrintStream;
import java.util.ArrayList;
import java.util.List;

%%

%class TranscriptParser
%implements ParserToJSON
%public
%unicode
%line
%column
%function parse
%type ParserToJSON
%scanerror IllegalStateException

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
    private String skip = "";
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

    private void resetSkip() {
        skip = "";
    }

    private void skipUnexpected(String str) {
        this.skip = this.skip + str;
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
Initials        = [:uppercase:][:letter:]*" "?[:uppercase:](\r|\n)
NotWS           = [^ \r\n\t\f]
LineContents    = [^\r\n]
EndUtterance    = {NotWS}
Utterance       = {LineContents}*{EndUtterance}
Timestamp       = [:digit:][:digit:]":"[:digit:][:digit:]":"[:digit:][:digit:]
EndOfTranscript = [eE][nN][dD]" "[oO][fF]" "[tT][rR][aA][nN][sS][cC][rR][iI][pP][tT]
/*
LowerFirst      = [:lowercase:]{NotWS}
LowerSecond     = {NotWS}[:lowercase:]
FollowOn        = {LowerFirst}|{LowerSecond} {LineContents}*
*/

%state DATE
%state EXPECT_SPEAKER
%state EXPECT_TIMESTAMP
%state EXPECT_UTTERANCE
%state EXPECT_SPEAKER_TIMESTAMP_OR_FOLLOWON
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
                            yybegin(EXPECT_SPEAKER);
                            date = yytext();
                        }
}

<EXPECT_SPEAKER> {
    {Whitespace}        { /* Ignore whitespace */ }
    {LineTerminator}    { /* Ignore line endings */ }

    ^{Initials}         {
                            yypushback(1);
                            currentSpeaker = yytext();
                            yybegin(EXPECT_TIMESTAMP);
                        }

    {EndOfTranscript}   {
                            yybegin(FINISHED);
                        }

    <<EOF>>             {
                            return this;
                        }
}

<EXPECT_TIMESTAMP> {
    {Whitespace}        { /* Ignore whitespace */ }
    {LineTerminator}    {
                            if (!skip.isEmpty()) {
                                throw new IllegalStateException("Invalid timestamp (" + skip +
                                    ") at " + yyline + ", columns " + (yycolumn - skip.length()) +
                                    "-" + yycolumn);
                            } else {
                                /* Ignore line endings */
                            }
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
                            if (!skip.isEmpty()) {
                                System.err.format(
                                    "Found Timestamp %s at line %d, Skipped over %s\n" +
                                    yytext().trim(), yycolumn, skip);
                            }
                            resetSkip();
                            yybegin(EXPECT_UTTERANCE);
                        }

    <<EOF>>             {
                            throw new IllegalStateException("Error at line " + yyline +
                                ": Unexpected end-of-file. Incomplete transcription for " +
                                "Speaker(" + currentSpeaker + ") skipped: '" + skip + "'");
                        }

    .                   {
                            skipUnexpected(yytext());
                        }
}

<EXPECT_UTTERANCE> {
    {Whitespace}        { /* Ignore whitespace */ }
    {LineTerminator}    { /* Ignore line endings */ }

    {Utterance}         {
                            String utterance = yytext().trim();
                            utterance = utterance.replace("\"", "\\\"");
                            utterance = utterance.replace("\\s\\s*", " ");
                            currentUtterance.appendUtterance(utterance);
                            yybegin(EXPECT_SPEAKER_TIMESTAMP_OR_FOLLOWON);
                        }

    <<EOF>>             {
                            throw new IllegalStateException("Error at line " + yyline +
                                ": Unexpected end-of-file. Incomplete transcription for " +
                                "Speaker(" + currentUtterance.getSpeaker() + "@" +
                                currentUtterance.getTimestamp() + ")");
                        }
}

<EXPECT_SPEAKER_TIMESTAMP_OR_FOLLOWON> {
    {Whitespace}        { /* Ignore whitespace */ }
    {LineTerminator}    { /* Ignore line endings */ }

    ^{Initials}        {
                            yypushback(1);
                            currentSpeaker = yytext();
                            yybegin(EXPECT_TIMESTAMP);
                        }

    {Timestamp}        {
                            if (currentSpeaker == null)
                                throw new IllegalStateException("Error at line " + yyline +
                                    ": Utterance without current speaker");

                            if (currentUtterance != null && currentUtterance.utterance == null)
                                throw new IllegalStateException("Error at line " + yyline +
                                    "(" + yytext() + ")" +
                                    ": New utterance detected before old utterance completed");

                            currentUtterance = new Utterance(currentSpeaker, yytext().trim());
                            interview.add(currentUtterance);
                            yybegin(EXPECT_UTTERANCE);
                        }

    {Utterance}          {
                            String utterance = yytext().trim();
                            utterance = utterance.replace("\"", "\\\"");
                            utterance = utterance.replace("\\s\\s*", " ");
                            currentUtterance.appendUtterance(utterance);
                        }

    {EndOfTranscript}   {
                            yybegin(FINISHED);
                        }

    <<EOF>>             {
                            return this;
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
