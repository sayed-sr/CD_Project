%option noyywrap
%option yylineno

%{
#include "yacc.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
%}

digit   [0-9]
letter  [A-Za-z_]
id      {letter}({letter}|{digit})*
integer {digit}+
float   {digit}+(\.{digit}+)

%%

"int"           { return INT; }
"float"         { return FLOAT_TYPE; }
"print"         { return PRINT; }
"if"            { return IF; }
"else"          { return ELSE; }
"while"         { return WHILE; }

"="             { return ASSIGN; }
";"             { return SEMI; }
"{"             { return LBRACE; }
"}"             { return RBRACE; }

"+"             { return PLUS; }
"-"             { return MINUS; }
"*"             { return MUL; }
"/"             { return DIV; }
"%"             { return MOD; }

"("             { return LPAREN; }
")"             { return RPAREN; }

"=="            { return EQ; }
"!="            { return NEQ; }
"<"             { return LT; }
">"             { return GT; }
"<="            { return LTE; }
">="            { return GTE; }

"&&"            { return AND; }
"||"            { return OR; }
"!"             { return NOT; }

{float}         { yylval.fnum = atof(yytext); return FLOAT_NUM; }
{integer}       { yylval.inum = atoi(yytext); return INT_NUM; }
{id}            { yylval.id = strdup(yytext); return ID; }

[ \t\r]+        { /* skip whitespace */ }
\n              { /* yylineno auto-increments */ }
"//".*          { /* skip single-line comments */ }

.               { fprintf(stderr, "Lexical Error (line %d): unknown character '%s'\n", yylineno, yytext); }

%%
