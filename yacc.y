%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex(void);
void yyerror(const char *s);
extern int yylineno;

/* ============================================================
   TAC (Three-Address Code) Generator
   ============================================================ */
#define MAX_TAC 1024

typedef struct {
    char op[16];
    char arg1[64];
    char arg2[64];
    char result[64];
} TACInstr;

static TACInstr tac[MAX_TAC];
static int tac_count = 0;

static int temp_count = 0;
static int label_count = 0;

static char* new_temp() {
    char *t = malloc(16);
    sprintf(t, "t%d", temp_count++);
    return t;
}

static char* new_label() {
    char *l = malloc(16);
    sprintf(l, "L%d", label_count++);
    return l;
}

static void emit(const char *op, const char *arg1, const char *arg2, const char *result) {
    if (tac_count >= MAX_TAC) {
        fprintf(stderr, "TAC Error: too many instructions\n");
        return;
    }
    strncpy(tac[tac_count].op,     op     ? op     : "", 15);
    strncpy(tac[tac_count].arg1,   arg1   ? arg1   : "", 63);
    strncpy(tac[tac_count].arg2,   arg2   ? arg2   : "", 63);
    strncpy(tac[tac_count].result, result ? result : "", 63);
    tac_count++;
}

static void print_tac() {
    printf("\n========== THREE-ADDRESS CODE ==========\n");
    for (int i = 0; i < tac_count; i++) {
        TACInstr *ins = &tac[i];

        if (strcmp(ins->op, "LABEL") == 0) {
            printf("%s:\n", ins->result);
        } else if (strcmp(ins->op, "GOTO") == 0) {
            printf("    goto %s\n", ins->result);
        } else if (strcmp(ins->op, "IF") == 0) {
            printf("    if %s %s %s goto %s\n", ins->arg1, ins->op+2 /* unused */, ins->arg2, ins->result);
        } else if (strcmp(ins->op, "IFFALSE") == 0) {
            printf("    ifFalse %s goto %s\n", ins->arg1, ins->result);
        } else if (strcmp(ins->op, "ASSIGN") == 0) {
            printf("    %s = %s\n", ins->result, ins->arg1);
        } else if (strcmp(ins->op, "PRINT") == 0) {
            printf("    print %s\n", ins->arg1);
        } else if (strcmp(ins->op, "DECL") == 0) {
            printf("    decl %s %s\n", ins->arg1, ins->result);
        } else {
            /* binary op: result = arg1 op arg2 */
            printf("    %s = %s %s %s\n", ins->result, ins->arg1, ins->op, ins->arg2);
        }
    }
    printf("=========================================\n\n");
}

/* ============================================================
   Symbol Table
   ============================================================ */
typedef enum { TYPE_INT, TYPE_FLOAT, TYPE_UNKNOWN } VarType;

typedef struct {
    char   *name;
    double  value;
    VarType type;
    int     declared;
    int     initialized;
} Symbol;

#define MAX_SYMS 512
static Symbol symtab[MAX_SYMS];
static int symcount = 0;
static int error_count = 0;

static int find_symbol(const char *name) {
    for (int i = 0; i < symcount; i++)
        if (symtab[i].declared && strcmp(symtab[i].name, name) == 0) return i;
    return -1;
}

static void declare_symbol(const char *name, VarType type) {
    if (find_symbol(name) != -1) {
        fprintf(stderr, "Semantic Error (line %d): '%s' already declared\n", yylineno, name);
        error_count++;
        return;
    }
    if (symcount >= MAX_SYMS) {
        fprintf(stderr, "Internal Error: symbol table full\n");
        return;
    }
    symtab[symcount].name        = strdup(name);
    symtab[symcount].value       = 0.0;
    symtab[symcount].type        = type;
    symtab[symcount].declared    = 1;
    symtab[symcount].initialized = 0;
    symcount++;
}

static void set_symbol(const char *name, double val) {
    int idx = find_symbol(name);
    if (idx == -1) {
        fprintf(stderr, "Semantic Error (line %d): '%s' not declared\n", yylineno, name);
        error_count++;
        return;
    }
    symtab[idx].value       = val;
    symtab[idx].initialized = 1;
}

static double get_symbol(const char *name) {
    int idx = find_symbol(name);
    if (idx == -1) {
        fprintf(stderr, "Semantic Error (line %d): '%s' not declared\n", yylineno, name);
        error_count++;
        return 0.0;
    }
    if (!symtab[idx].initialized) {
        fprintf(stderr, "Semantic Error (line %d): '%s' used before assignment\n", yylineno, name);
        error_count++;
        return 0.0;
    }
    return symtab[idx].value;
}

static const char* type_name(VarType t) {
    return (t == TYPE_INT) ? "int" : (t == TYPE_FLOAT) ? "float" : "unknown";
}

%}

%union {
    int    inum;
    double fnum;
    char  *id;
    double eval;   /* expression value for interpreter */
    char  *tname;  /* TAC temp/var name */
}

/* --- tokens --- */
%token INT FLOAT_TYPE PRINT IF ELSE WHILE
%token ASSIGN SEMI LBRACE RBRACE
%token PLUS MINUS MUL DIV MOD
%token LPAREN RPAREN
%token EQ NEQ LT GT LTE GTE
%token AND OR NOT

%token <inum> INT_NUM
%token <fnum> FLOAT_NUM
%token <id>   ID

/* --- non-terminal types --- */
%type <tname> expr term factor cond
%type <id>    type

/* --- precedence (low to high) --- */
%right ASSIGN
%left  OR
%left  AND
%right NOT
%left  EQ NEQ
%left  LT GT LTE GTE
%left  PLUS MINUS
%left  MUL DIV MOD
%right UMINUS

%%

program
    : statements
      {
        /* Print TAC after full parse */
        print_tac();
        if (error_count > 0)
            fprintf(stderr, "\n%d semantic error(s) found.\n", error_count);
      }
    ;

statements
    : statements statement
    | /* empty */
    ;

statement
    : decl
    | assign_stmt
    | print_stmt
    | if_stmt
    | while_stmt
    | LBRACE statements RBRACE
    ;

/* ---- Declaration ---- */
type
    : INT        { $$ = "int"; }
    | FLOAT_TYPE { $$ = "float"; }
    ;

decl
    : type ID SEMI
      {
        VarType vt = (strcmp($1,"int")==0) ? TYPE_INT : TYPE_FLOAT;
        declare_symbol($2, vt);
        emit("DECL", $1, NULL, $2);
        free($2);
      }
    ;

/* ---- Assignment ---- */
assign_stmt
    : ID ASSIGN expr SEMI
      {
        int idx = find_symbol($1);
        if (idx == -1) {
            fprintf(stderr, "Semantic Error (line %d): '%s' not declared\n", yylineno, $1);
            error_count++;
        } else {
            /* type check: warn if float assigned to int */
            /* (simple: we trust the interpreter value) */
            set_symbol($1, 0.0 /* placeholder; real val computed at runtime */);
        }
        emit("ASSIGN", $3, NULL, $1);
        free($1);
        free($3);
      }
    ;

/* ---- Print ---- */
print_stmt
    : PRINT LPAREN expr RPAREN SEMI
      {
        emit("PRINT", $3, NULL, NULL);
        free($3);
      }
    ;

/* ---- If / Else ---- */
if_stmt
    : IF LPAREN cond RPAREN
      {
        /* We emit IFFALSE cond goto Lfalse before body */
        char *lfalse = new_label();
        char *lend   = new_label();
        emit("IFFALSE", $3, NULL, lfalse);
        /* push labels onto a small stack via globals — simple approach */
        /* We'll use a workaround: store them in a static array */
        extern void push_labels(const char*, const char*);
        push_labels(lfalse, lend);
        free($3);
      }
      statement
      {
        extern void pop_labels(char**, char**);
        char *lfalse, *lend;
        pop_labels(&lfalse, &lend);
        emit("GOTO", NULL, NULL, lend);
        emit("LABEL", NULL, NULL, lfalse);
        free(lfalse);
        /* lend still needed */
        extern void push_end_label(const char*);
        push_end_label(lend);
      }
      else_part
      {
        extern void pop_end_label(char**);
        char *lend;
        pop_end_label(&lend);
        emit("LABEL", NULL, NULL, lend);
        free(lend);
      }
    ;

else_part
    : ELSE statement
    | /* empty */
    ;

/* ---- While ---- */
while_stmt
    : WHILE LPAREN
      {
        char *lstart = new_label();
        emit("LABEL", NULL, NULL, lstart);
        extern void push_while_start(const char*);
        push_while_start(lstart);
      }
      cond RPAREN
      {
        char *lend = new_label();
        emit("IFFALSE", $4, NULL, lend);
        extern void push_while_end(const char*);
        push_while_end(lend);
        free($4);
      }
      statement
      {
        extern void pop_while_labels(char**, char**);
        char *lstart, *lend;
        pop_while_labels(&lstart, &lend);
        emit("GOTO", NULL, NULL, lstart);
        emit("LABEL", NULL, NULL, lend);
        free(lstart);
        free(lend);
      }
    ;

/* ---- Conditions ---- */
cond
    : expr EQ  expr { char *t=new_temp(); emit("==", $1,$3,t); free($1);free($3); $$=t; }
    | expr NEQ expr { char *t=new_temp(); emit("!=", $1,$3,t); free($1);free($3); $$=t; }
    | expr LT  expr { char *t=new_temp(); emit("<",  $1,$3,t); free($1);free($3); $$=t; }
    | expr GT  expr { char *t=new_temp(); emit(">",  $1,$3,t); free($1);free($3); $$=t; }
    | expr LTE expr { char *t=new_temp(); emit("<=", $1,$3,t); free($1);free($3); $$=t; }
    | expr GTE expr { char *t=new_temp(); emit(">=", $1,$3,t); free($1);free($3); $$=t; }
    | cond AND cond { char *t=new_temp(); emit("&&", $1,$3,t); free($1);free($3); $$=t; }
    | cond OR  cond { char *t=new_temp(); emit("||", $1,$3,t); free($1);free($3); $$=t; }
    | NOT cond      { char *t=new_temp(); emit("!",  $2,NULL,t); free($2); $$=t; }
    ;

/* ---- Expressions ---- */
expr
    : expr PLUS  term { char *t=new_temp(); emit("+", $1,$3,t); free($1);free($3); $$=t; }
    | expr MINUS term { char *t=new_temp(); emit("-", $1,$3,t); free($1);free($3); $$=t; }
    | term            { $$=$1; }
    ;

term
    : term MUL factor { char *t=new_temp(); emit("*", $1,$3,t); free($1);free($3); $$=t; }
    | term DIV factor { char *t=new_temp(); emit("/", $1,$3,t); free($1);free($3); $$=t; }
    | term MOD factor { char *t=new_temp(); emit("%", $1,$3,t); free($1);free($3); $$=t; }
    | factor          { $$=$1; }
    ;

factor
    : INT_NUM
      {
        char *t = new_temp();
        char buf[32]; sprintf(buf, "%d", $1);
        emit("ASSIGN", buf, NULL, t);
        $$ = t;
      }
    | FLOAT_NUM
      {
        char *t = new_temp();
        char buf[32]; sprintf(buf, "%g", $1);
        emit("ASSIGN", buf, NULL, t);
        $$ = t;
      }
    | ID
      {
        int idx = find_symbol($1);
        if (idx == -1) {
            fprintf(stderr, "Semantic Error (line %d): '%s' not declared\n", yylineno, $1);
            error_count++;
        } else if (!symtab[idx].initialized) {
            fprintf(stderr, "Semantic Warning (line %d): '%s' may be uninitialized\n", yylineno, $1);
        }
        $$ = $1; /* use the variable name directly as TAC operand */
      }
    | LPAREN expr RPAREN { $$=$2; }
    | MINUS factor %prec UMINUS
      {
        char *t = new_temp();
        emit("NEG", $2, NULL, t);
        free($2);
        $$ = t;
      }
    ;

%%

/* ============================================================
   Label stack helpers (for if/else and while)
   ============================================================ */
#define STACK_SIZE 128

/* if/else stacks */
static char *lfalse_stack[STACK_SIZE];
static char *lend_stack_if[STACK_SIZE];
static int if_top = 0;

void push_labels(const char *lf, const char *le) {
    lfalse_stack[if_top]   = strdup(lf);
    lend_stack_if[if_top]  = strdup(le);
    if_top++;
}
void pop_labels(char **lf, char **le) {
    if_top--;
    *lf = lfalse_stack[if_top];
    *le = lend_stack_if[if_top];
}

static char *end_label_stack[STACK_SIZE];
static int end_top = 0;

void push_end_label(const char *le) { end_label_stack[end_top++] = strdup(le); }
void pop_end_label(char **le)       { *le = end_label_stack[--end_top]; }

/* while stacks */
static char *while_start_stack[STACK_SIZE];
static char *while_end_stack[STACK_SIZE];
static int while_top = 0;

void push_while_start(const char *ls) { while_start_stack[while_top++] = strdup(ls); }
void push_while_end(const char *le)   { while_end_stack[while_top-1]   = strdup(le); }
void pop_while_labels(char **ls, char **le) {
    while_top--;
    *ls = while_start_stack[while_top];
    *le = while_end_stack[while_top];
}

/* ============================================================
   Error handler & main
   ============================================================ */
void yyerror(const char *s) {
    fprintf(stderr, "Syntax Error (line %d): %s\n", yylineno, s);
    error_count++;
}

int main(void) {
    printf("=========================================\n");
    printf("  MiniLang Compiler  (Lex + Yacc + TAC)  \n");
    printf("=========================================\n");
    int result = yyparse();
    if (result == 0 && error_count == 0) {
        printf("Compilation successful! No errors.\n");
    } else {
        printf("Compilation finished with errors.\n");
    }
    return result;
}
