/*** JFlex specification for Bash ****
    The Bash language is a beast. It contains many strange or unusual constructs
    and has a great flexibility in what is possible.
    The lexer tries to do as much as possible in the lexing phase to help the parser
    later on.

    A major problem is that tokens have to interpreted according to their context.
    e.g. a=b echo a=b
    has an assignment in front and a string as parameter to the echo command. So the EQ
    token (for the = character) has to be remapped to a WORD later on (see BashTokenTypeRemapper).

    Another problem is that string can contain unescaped substrings, e.g.
        "$(echo hello "$(echo "world")")" is just one string. But this string contains
    two levels of embedded strings in the embedded subshell command.
    The lexer parses a string as STRING_BEGIN, STRING_CHAR and STRING_END. These
    tokens are mapped to a STRING later on by the lexer.MergingLexer class.

    Lexing all as a STRING token was the way to go. This worked, but for some strange
    reason the lexer got wrong offsets for this complex setup (returning the string only at the
    last occurence of "). That's why the token merging strategy was established.

    If you really want to hack on this lexer: Be careful :)
    There are unit tests for the lexer but there's no 100% coverage for all cases.

     @author Joachim Ansorg, mail@ansorg-it.com
**/

/** Based on the arc lexer (http://code.google.com/p/intelli-arc/) **/

package com.ansorgit.plugins.bash.lang.lexer;

import com.intellij.lexer.FlexLexer;
import com.intellij.psi.tree.IElementType;
import static com.ansorgit.plugins.bash.lang.lexer.BashTokenTypes.*;

import com.intellij.util.containers.Stack;

%%

%class _BashLexer
%implements FlexLexer
%unicode
%public
%char

%function advance
%type IElementType

%{
  private Stack<Integer> lastStates = new Stack<Integer>(25);
  private int openParenths = 0;
  private boolean isBash4 = false;

  public _BashLexer(com.ansorgit.plugins.bash.lang.BashVersion version, java.io.Reader in) {
    this(in);
    this.isBash4 = com.ansorgit.plugins.bash.lang.BashVersion.Bash_v4.equals(version);
  }

  /**
  * Goes to the given state and stores the previous state on the stack of states.
  * This makes it possible to have several levels of lexing, e.g. for $(( 1+ $(echo 3) )).
  */
  private void goToState(Integer newState) {
    lastStates.push(yystate());
    yybegin(newState);
  }

  /**
  * Goes back to the previous state of the lexer. If there
  * is no previous state then YYINITIAL, the initial state, is chosen.
  */
  private void backToPreviousState() {
    if (lastStates.isEmpty()) {
      throw new IllegalStateException("BashLexer: Tried to go to previous state, but not more state left.");
    }
    else {
      yybegin(lastStates.pop());
    }
  }

  //True if the parser is in the case body. Necessary for proper lexing of the IN keyword
  private boolean inCaseBody = false;

  //True if an arithmetic expression is expected as next token (e.g. in $((a-$((1+34)))) ) we need to
  //discern between a simple ( and the start of a new subexpression
  private boolean expectArithExpression = false;

  //Help data to parse (nested) strings.
  private final StringParsingState string = new StringParsingState();

  //helper
  long yychar = 0;
%}

/***** Custom user code *****/

LineTerminator = \r\n | \r | \n
InputCharacter = [^\r\n]
WhiteSpace=[ \t\f]
ContinuedLine = "\\" {LineTerminator}

Shebang = "#!" {InputCharacter}* {LineTerminator}?
Comment = "#"  {InputCharacter}*
Comments = {Comment}({Comment}{LineTerminator})*

EscapedChar = "\\" [^\n]
StringStart = "$\"" | "\""
SingleCharacter = [^\'] | {EscapedChar}

WordFirst = [a-zA-Z0-9] | "_" | "/" | "@" | "?" | "." | "*" | ":" | "&" | "%"
    | "-" | "^" | "+" | "-" | "," | "~" | "*"
    | {EscapedChar}
WordAfter =  {WordFirst} | "#" | "[" | "]" | "!"

ArithWordFirst = [a-zA-Z] | "_" | "@" | "?" | "." | ":" | {EscapedChar}
ArithWordAfter =  {ArithWordFirst} | "#" | "[" | "]" | "!"

AssignListWordFirst = [a-zA-Z0-9] | "_" | "/" | "@" | "?" | "." | "*" | ":" | "&" | "%"
    | "-" | "^" | "+" | "-" | "~" | "*"
    | {EscapedChar}
AssignListWordAfter =  {AssignListWordFirst} | "$" | "#" | "[" | "]" | "!"

Word = {WordFirst}{WordAfter}*
ArithWord = {ArithWordFirst}{ArithWordAfter}*
AssignmentWord = [a-zA-Z_][a-zA-Z0-9_]*
ArrayAssignmentWord = [a-zA-Z_][a-zA-Z0-9_]* "[" [0-9+*/-]+ "]"
Variable = "$" {AssignmentWord} | "$@" | "$$" | "$#" | "$"[0-9] | "$?" | "$!" | "$*"

IntegerLiteral = [0] | ([1-9][0-9]*)
BaseIntegerLiteral = [1-9][0-9]* "#" [0-9a-zA-Z@_]+
HexIntegerLiteral = "0x" [0-9a-fA-F]+
OctalIntegerLiteral = "0" [0-7]+

AssignListWord={AssignListWordFirst}{AssignListWordAfter}*

CaseFirst=[^|)(# \n\r\f\t\f]
CaseAfter=[^|)( \n\r\f\t\f]
CasePattern = {CaseFirst}{CaseAfter}*

Filedescriptor = "&" {IntegerLiteral} | "&-"

/************* STATES ************/
/* If in a conditional expression */
%state S_TEST

/*  If in an arithmetic expression */
%state S_ARITH

/*  If in a case */
%state S_CASE

/*  If in a case pattern */
%state S_CASE_PATTERN

/*  If in a arithmetic subshell */
%state S_SUBSHELL

/*  If in a assignment */
%state S_ARRAYASSIGN

/*  If currently a string is parsed */
%xstate S_STRINGMODE

/*  To match tokens in pattern expansion mode ${...} . Needs special parsing of # */
%state S_PARAM_EXPANSION

/* To match tokens which are in between backquotes. Necessary for nested lexing, e.g. inside of conditional expressions */
%state S_BACKQUOTE

%%
/***************************** INITIAL STAATE ************************************/
<YYINITIAL, S_CASE, S_CASE_PATTERN, S_SUBSHELL> {
  {Shebang}                     { return SHEBANG; }
  {Comments}                    { return COMMENT; }
}

<YYINITIAL, S_CASE, S_SUBSHELL, S_BACKQUOTE> {
  "[ "                          { goToState(S_TEST); return EXPR_CONDITIONAL; }

  /** Strings */
  <S_ARRAYASSIGN> {
    {IntegerLiteral}            { return INTEGER_LITERAL; }
  }

  "time"                        { return TIME_KEYWORD; }

/** Builtin commands */
   "."                          |
   ":"                          |
   "alias"                      |
   "bg"                         |
   "bind"                       |
   "break"                      |
   "builtin"                    |
   "cd"                         |
   "caller"                     |
   "command"                    |
   "compgen"                    |
   "complete"                   |
   "continue"                   |
   "declare"                    |
   "typeset"                    |
   "dirs"                       |
   "disown"                     |
   "echo"                       |
   "enable"                     |
   "eval"                       |
   "exec"                       |
   "exit"                       |
   "export"                     |
   "fc"                         |
   "fg"                         |
   "getopts"                    |
   "hash"                       |
   "help"                       |
   "history"                    |
   "jobs"                       |
   "kill"                       |
   "let"                        |
   "local"                      |
   "logout"                     |
   "popd"                       |
   "printf"                     |
   "pushd"                      |
   "pwd"                        |
   "read"                       |
   "readonly"                   |
   "return"                     |
   "set"                        |
   "shift"                      |
   "shopt"                      |
   "unset"                      |
   "source"                     |
   "suspend"                    |
   "test"                       |
   "times"                      |
   "trap"                       |
   "type"                       |
   "ulimit"                     |
   "umask"                      |
   "unalias"                    |
   "wait"                       { return INTERNAL_COMMAND; }

   <S_STRINGMODE, S_ARITH> {
       "&&"                         { return AND_AND; }

       "||"                         { return OR_OR; }
   }
}

<YYINITIAL, S_CASE, S_SUBSHELL, S_BACKQUOTE> {
    <S_ARITH> {
       {ArrayAssignmentWord} / "=("|"+=("   { goToState(S_ARRAYASSIGN); return ARRAY_ASSIGNMENT_WORD; }
       {AssignmentWord} / "=("|"+=("        { goToState(S_ARRAYASSIGN); return ASSIGNMENT_WORD; }

       {ArrayAssignmentWord} / "="|"+="   { return ARRAY_ASSIGNMENT_WORD; }
       {AssignmentWord} / "="|"+="        { return ASSIGNMENT_WORD; }
       "="                                { return EQ; }
   }
   
   "+="                               { return ADD_EQ; }
}

<S_ARRAYASSIGN> {
  "+="                            { return ADD_EQ; }
  "="                             { return EQ; }
  "("                             { return LEFT_PAREN; }

  <S_ARITH> {
    ","                             { return COMMA; }
  }

  {AssignListWord}                { return WORD; }
  ")"                             { backToPreviousState(); return RIGHT_PAREN; }
}

<YYINITIAL, S_SUBSHELL> {
  "in"                          { return IN_KEYWORD; }
}

<YYINITIAL, S_CASE, S_SUBSHELL> {
/* keywords and expressions */
  "case"                        { inCaseBody = false; goToState(S_CASE); return CASE_KEYWORD; }

  "!"                           { return BANG_TOKEN; }
  "do"                          { return DO_KEYWORD; }
  "done"                        { return DONE_KEYWORD; }
  "elif"                        { return ELIF_KEYWORD; }
  "else"                        { return ELSE_KEYWORD; }
  "fi"                          { return FI_KEYWORD; }
  "for"                         { return FOR_KEYWORD; }
  "function"                    { return FUNCTION_KEYWORD; }
  "if"                          { return IF_KEYWORD; }
  "select"                      { return SELECT_KEYWORD; }
  "then"                        { return THEN_KEYWORD; }
  "until"                       { return UNTIL_KEYWORD; }
  "while"                       { return WHILE_KEYWORD; }
  "[[ "                         { return BRACKET_KEYWORD; }
  " ]]"                         { return _BRACKET_KEYWORD; }
}
/***************** _______ END OF INITIAL STAATE _______ **************************/

<S_TEST> {
  " ]"                         { backToPreviousState(); return _EXPR_CONDITIONAL; }
  {WhiteSpace}                 { return WHITESPACE; }
  {ContinuedLine}+             { /* ignored */ }

/** Test / conditional expressions */
  /* misc */
  "!"                          |
  "-a"                         |
  "-o"                         |
  "-eq"                        |
  "-ne"                        |
  "-lt"                        |
  "-le"                        |
  "-gt"                        |
  "-ge"                        |

  /* string operators */
  "!="                         |
  ">"                          |
  "<"                          |
  "="                          |
  "-n"                         |
  "-z"                         |

  /* conditional operators */
  "-nt"                        |
  "-ot"                        |
  "-ef"                        |
  "-n"                         |
  "-o"                         |
  "-qq"                        |
  "-a"                         |
  "-b"                         |
  "-c"                         |
  "-d"                         |
  "-e"                         |
  "-f"                         |
  "-g"                         |
  "-h"                         |
  "-k"                         |
  "-p"                         |
  "-r"                         |
  "-s"                         |
  "-t"                         |
  "-u"                         |
  "-w"                         |
  "-x"                         |
  "-O"                         |
  "-G"                         |
  "-L"                         |
  "-S"                         |
  "-N"                         { return COND_OP; }
}

<S_ARITH, S_TEST, S_PARAM_EXPANSION, S_SUBSHELL> {
  /* If a subshell expression is found, return DOLLAR and move before the bracket */
  "$("/[^(]                     { yypushback(1); goToState(S_SUBSHELL); return DOLLAR; }
}

/*** Arithmetic expressions *************/
<S_ARITH> {
  "))"                          { if (openParenths > 0) {
                                    openParenths--; yypushback(1); return RIGHT_PAREN;}
                                  else {
                                    string.advanceToken();
                                    backToPreviousState();
                                    return _EXPR_ARITH;
                                  }
                                }

  ")"                           { openParenths--; return RIGHT_PAREN; }

  "$(("                         { yypushback(2); expectArithExpression = true; return DOLLAR; }
  "(("                          { if (expectArithExpression) {
                                    expectArithExpression = false;
                                    goToState(S_ARITH);
                                    return EXPR_ARITH;
                                  } else {
                                    yypushback(1);
                                    openParenths++;
                                    return LEFT_PAREN;
                                  }
                                }

  "("                           { openParenths++; return LEFT_PAREN; }

  {HexIntegerLiteral}           { return ARITH_HEX_NUMBER; }
  {BaseIntegerLiteral}          { return ARITH_BASE_NUMBER; }
  {OctalIntegerLiteral}         { return ARITH_OCTAL_NUMBER; }
  {IntegerLiteral}              { return NUMBER; }

  ">"                           { return ARITH_GT; }
  "<"                           { return ARITH_LT; }
  ">="                          { return ARITH_GE; }
  "<="                          { return ARITH_LE; }
  "!="                          { return ARITH_NE; }

  "<<"                          { return ARITH_SHIFT_LEFT; }
  ">>"                          { return ARITH_SHIFT_RIGHT; }

  "*="                          { return ARITH_ASS_MUL; }
  "/="                          { return ARITH_ASS_DIV; }
  "%="                          { return ARITH_ASS_MOD; }
  "+="                          { return ARITH_ASS_PLUS; }
  "-="                          { return ARITH_ASS_MINUS; }
  ">>="                         { return ARITH_ASS_SHIFT_RIGHT; }
  "<<="                         { return ARITH_ASS_SHIFT_LEFT; }

  "+"                           { return ARITH_PLUS; }
  "++"                          { return ARITH_PLUS_PLUS; }
  "-"                           { return ARITH_MINUS; }

  "--"/"-"
                                { yypushback(1); return ARITH_MINUS; }

  "--"/{WhiteSpace}+"-"
                                { yypushback(1); return ARITH_MINUS; }

  "--"/({HexIntegerLiteral}|{BaseIntegerLiteral}|{BaseIntegerLiteral}|{OctalIntegerLiteral}|{IntegerLiteral})
                                { yypushback(1); return ARITH_MINUS; }

  "--"/{WhiteSpace}+({HexIntegerLiteral}|{BaseIntegerLiteral}|{OctalIntegerLiteral}|{IntegerLiteral})
                                { yypushback(1); return ARITH_MINUS; }

  "--"                          { return ARITH_MINUS_MINUS; }
  "=="                          { return ARITH_EQ; }

  "**"                          { return ARITH_EXPONENT; }
  "*"                           { return ARITH_MULT; }
  "/"                           { return ARITH_DIV; }
  "%"                           { return ARITH_MOD; }
  "<<"                          { return ARITH_SHIFT_LEFT; }

  "!"                           { return ARITH_NEGATE; }

  "&"                           { return ARITH_BITWISE_AND; }
  "~"                           { return ARITH_BITWISE_NEGATE; }
  "^"                           { return ARITH_BITWISE_XOR; }

  "?"                           { return ARITH_QMARK; }
  ":"                           { return ARITH_COLON; }

  {ArithWord}                   { return WORD; }
}

<S_SUBSHELL> {
  ")"                           { backToPreviousState(); return RIGHT_PAREN; }
}

<S_CASE> {
  "esac"                       { backToPreviousState(); return ESAC_KEYWORD; }

  ";&"                         { goToState(S_CASE_PATTERN);
                                 if (isBash4) {
                                    return CASE_END;
                                 }
                                 else {
                                    yypushback(1);
                                    return SEMI;
                                 }
                               }
  
  ";;&"                        { goToState(S_CASE_PATTERN);
                                 if (!isBash4) {
                                    yypushback(1);
                                 }
                                 return CASE_END;
                               }

  ";;"                         { goToState(S_CASE_PATTERN); return CASE_END; }
  "in"                         { if (!inCaseBody) { inCaseBody = true; goToState(S_CASE_PATTERN); }; return IN_KEYWORD; }
}

<S_CASE_PATTERN> {
  "esac"                        { backToPreviousState(); yypushback(yylength()); }
  {CasePattern}                 { return WORD; }
  ")"                           { backToPreviousState(); yypushback(1); }
}

//////////////////// END OF STATE TEST_EXPR /////////////////////

/* string literals */
 <S_STRINGMODE> {
  {EscapedChar}                 { return WORD; }

  \"                            { if (string.isNewAllowed()) {
                                    string.enterSubstring(); return STRING_CHAR;
                                  } else if (string.isInSubstring()) {
                                    string.leaveSubstring(); return STRING_CHAR;
                                  } else {
                                    backToPreviousState();
                                    return STRING_END;
                                  }
                                }

  "$(("                       { yypushback(2); return DOLLAR; }
  "$("                        { string.enterSubshell(); yypushback(1); return DOLLAR; }

  ")"                         { if (string.isInSubshell() && !string.isInSubstring()) {
                                      string.leaveSubshell();
                                      return RIGHT_PAREN;
                                }

                                return STRING_CHAR;
                              }

  /* Backquote expression */
  `                           { if (yystate() == S_BACKQUOTE) backToPreviousState(); else goToState(S_BACKQUOTE); return BACKQUOTE; }

  {Variable}                  { return VARIABLE; }
  "$"                         { return DOLLAR; }


  "("                        { if (string.isInSubshell()) {
                                    if (!string.isFreshSubshell()) string.enterSubshellParenth();
                                    string.advanceToken();
                                    return LEFT_PAREN;
                                }
                                else {
                                    string.advanceToken();
                                    return WORD;
                                }
                              }


 "|&"                         { string.advanceToken();
                                if (isBash4) {
                                    return (string.isInSubshell() && !string.isInSubstring()) ? PIPE_AMP : WORD;
                                } else {
                                    yypushback(1);
                                    return (string.isInSubshell() && !string.isInSubstring()) ? PIPE : WORD;
                                }
                              }

  "|"                         { string.advanceToken(); return (string.isInSubshell() && !string.isInSubstring()) ? PIPE : WORD; }


  "{"                         { string.advanceToken(); return LEFT_CURLY; }

  " "                         { string.advanceToken(); return (string.isInSubshell() && !string.isInSubstring()) ? WHITESPACE : STRING_CHAR; }

  [^\"]                       { string.advanceToken(); return STRING_CHAR; }
}  

<YYINITIAL, S_BACKQUOTE, S_SUBSHELL, S_CASE> {
  /* Bash 4 */
    "&>>"                         { if (isBash4) {
                                        return REDIRECT_AMP_GREATER_GREATER;
                                    } else {
                                        yypushback(2);
                                        return AMP;
                                    }
                                  }

    "&>"                          { if (isBash4) {
                                        return REDIRECT_AMP_GREATER;
                                    } else {
                                        yypushback(1);
                                        return AMP;
                                    }
                                  }

  /* Bash v3 */
  "<<<"                         { return REDIRECT_LESS_LESS_LESS; }
  "<<"                          { return REDIRECT_LESS_LESS; }
  "<<-"                         { return REDIRECT_LESS_LESS_MINUS; }
  "<>"                          { return REDIRECT_LESS_GREATER; }

  "<&" / {ArithWord}            { return REDIRECT_LESS_AMP; }
  ">&" / {ArithWord}            { return REDIRECT_GREATER_AMP; }
  "<&" / {WhiteSpace}           { return REDIRECT_LESS_AMP; }
  ">&" / {WhiteSpace}           { return REDIRECT_GREATER_AMP; }

  ">|"                          { return REDIRECT_GREATER_BAR; }

  {Filedescriptor}              { return FILEDESCRIPTOR; }              
}

<S_PARAM_EXPANSION> {
  "#"|"-"|"+" |"!"|"%"|":"|"*"|"@"|"/"|"?"|"="|"."|"^"
                                { return PARAM_EXPANSION_OP; }
  "["                           { return LEFT_SQUARE; }
  "]"                           { return RIGHT_SQUARE; }
  "{"                           { return LEFT_CURLY; }
  "}"                           { backToPreviousState(); return RIGHT_CURLY; }
  {EscapedChar}                 { return WORD; }
  {IntegerLiteral}              { return WORD; }
  {AssignmentWord}              { return WORD; }
 }


/** Match in all except of string */
<YYINITIAL, S_ARITH, S_CASE, S_CASE_PATTERN, S_SUBSHELL, S_ARITH, S_ARRAYASSIGN, S_PARAM_EXPANSION, S_BACKQUOTE, S_STRINGMODE> {
  /* Matching in all states */
    /*
     Do NOT match for Whitespace+ , we have some whitespace sensitive tokens like " ]]" which won't match
     if we match repeated whtiespace! 
    */
    {WhiteSpace}                 { return WHITESPACE; }
    {ContinuedLine}+             { /* ignored */ }
}

<YYINITIAL, S_TEST, S_ARITH, S_CASE, S_CASE_PATTERN, S_SUBSHELL, S_ARITH, S_ARRAYASSIGN, S_PARAM_EXPANSION, S_BACKQUOTE> {
    {StringStart}                 { string.reset(); goToState(S_STRINGMODE); return STRING_BEGIN; }

    "$"\'{SingleCharacter}*\'     |
    \'{SingleCharacter}*\'        { return STRING2; }

    /* Single line feeds are required to properly parse heredocs*/
    {LineTerminator}             { return LINE_FEED; }

    /* Backquote expression */
    `                             { if (yystate() == S_BACKQUOTE) backToPreviousState(); else goToState(S_BACKQUOTE); return BACKQUOTE; }


  /* Bash reserved keywords */
    "("                           { return LEFT_PAREN; }

    ")"                           { return RIGHT_PAREN; }

    "{"                           { return LEFT_CURLY; }

    "|&"                          { if (isBash4)
                                        return PIPE_AMP; 
                                     else {
                                        yypushback(1);
                                        return PIPE;
                                     }
                                  }
    "|"                           { return PIPE; }

  /** Misc expressions */
    "&"                           { return AMP; }
    "@"                           { return AT; }
    "$"                           { return DOLLAR; }
    ";"                           { return SEMI; }
    ">"                           { return GREATER_THAN; }
    "<"                           { return LESS_THAN; }
    ">>"                          { return SHIFT_RIGHT; }

    <S_STRINGMODE> {
      /* Arithmetic expression */
        "(("                         { goToState(S_ARITH); return EXPR_ARITH; }

      /** Variables */
        {Variable}                    { return VARIABLE; }
    }

    "["                           { return LEFT_SQUARE; }
    "]"                           { return RIGHT_SQUARE; }

    "\\"                          { return BACKSLASH; }
}

<YYINITIAL, S_PARAM_EXPANSION, S_TEST, S_ARITH, S_CASE, S_CASE_PATTERN, S_SUBSHELL, S_ARITH, S_ARRAYASSIGN, S_BACKQUOTE, S_STRINGMODE> {
    "${"                          { goToState(S_PARAM_EXPANSION); yypushback(1); return DOLLAR; }
    "}"                           { return RIGHT_CURLY; }
}    


<YYINITIAL, S_CASE, S_TEST, S_SUBSHELL, S_BACKQUOTE> {
  {Word}                          { return WORD; }
}


/** END */
  .                               { return BAD_CHARACTER; }
  