package net.qldarch.av.parser;

import java.io.PrintStream;
import java.util.ArrayList;
import java.util.List;

public class TranscriptParserMain {
    /**
     * Runs the scanner on input files.
     *
     * This is a standalone scanner, it will print any unmatched
     * text to System.out unchanged.
     *
     * @param argv   the command line, contains the filenames to run
     *               the scanner on.
     */
    public static void main(String argv[]) {
        if (argv.length == 0) {
            System.out.println("Usage : java TranscriptParser <inputfile>");
        } else {
            for (int i = 0; i < argv.length; i++) {
                try {
                    TranscriptParser scanner = null;
                    scanner = new TranscriptParser(new java.io.FileReader(argv[i]));
                    if (scanner.parse() == null) {
                        System.out.println("Parse failed");
                    } else {
                        scanner.printJson(System.out);
                    }
                    System.out.flush();
                } catch (java.io.FileNotFoundException e) {
                    System.out.println("File not found : \""+argv[i]+"\"");
                } catch (java.io.IOException e) {
                    System.out.println("IO error scanning file \""+argv[i]+"\"");
                    System.out.println(e);
                } catch (IllegalStateException e) {
                    System.out.println("Invalid input file:");
                    e.printStackTrace();
                } catch (Exception e) {
                    System.out.println("Unexpected exception:");
                    e.printStackTrace();
                }
            }
        }
    }


}
