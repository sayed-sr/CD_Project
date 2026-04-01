# MiniLang Compiler
### A Compiler for a Mini Programming Language
**Built with:** Lex (Flex) + Yacc (Bison) + C  
**Course:** Compiler Design

---

## What MiniLang Does

MiniLang is a compiler for a small, statically-typed programming language.  
It processes source code through **four phases** of compilation and outputs
**Three-Address Code (TAC)** — the standard intermediate representation used
in real compilers like GCC and LLVM.

---

## Language Features

| Feature         | Syntax Example                   |
|-----------------|----------------------------------|
| Int declaration | `int a;`                         |
| Float declaration | `float x;`                     |
| Assignment      | `a = 5;`                         |
| Arithmetic      | `a + b * 2 - c / d % 3`         |
| Print           | `print(expr);`                   |
| If / Else       | `if (a > b) { ... } else { ... }`|
| While loop      | `while (i < 10) { ... }`         |
| Comparisons     | `== != < > <= >=`                |
| Logical ops     | `&& \|\| !`                      |
| Comments        | `// this is a comment`           |
| Unary minus     | `-a`                             |

---

## Compilation Phases

### Phase 1 — Lexical Analysis (`lex.l`)
The **lexer** reads raw source text and converts it into a stream of tokens.
- Recognises keywords: `int`, `float`, `print`, `if`, `else`, `while`
- Recognises operators, identifiers, integer literals, float literals
- Reports **lexical errors** for unknown characters

### Phase 2 — Syntax Analysis (`yacc.y`)
The **parser** checks that the token stream follows the grammar of MiniLang.
- Grammar is specified as BNF rules in Yacc
- Reports **syntax errors** with line numbers
- Handles operator precedence and associativity correctly

### Phase 3 — Semantic Analysis (`yacc.y` — symbol table)
The **symbol table** tracks all declared variables and enforces:
- No variable used before declaration
- No variable used before assignment (initialization check)
- No duplicate declarations
- Type information stored per variable (`int` or `float`)
- **Semantic errors** reported with line numbers

### Phase 4 — Intermediate Code Generation (`yacc.y` — TAC)
The compiler generates **Three-Address Code (TAC)**:
- Every instruction has at most 3 operands: `result = arg1 op arg2`
- Temporary variables (`t0`, `t1`, ...) hold intermediate values
- Labels (`L0`, `L1`, ...) mark branch targets for `if` and `while`
- TAC can be directly translated to assembly or bytecode in a real compiler

---

## Three-Address Code Examples

### Arithmetic
```
int a; int b; int c;
a = 5;
b = a + 10;
c = a * 2 + b;
```
Produces:
```
    decl int a
    decl int b
    decl int c
    t0 = 5
    a = t0
    t1 = a
    t2 = 10
    t3 = t1 + t2
    b = t3
    ...
```

### If/Else
```
if (a > b) { print(a); } else { print(b); }
```
Produces:
```
    t0 = a > b
    ifFalse t0 goto L0
    print a
    goto L1
L0:
    print b
L1:
```

### While Loop
```
while (i < 3) { i = i + 1; }
```
Produces:
```
L0:
    t0 = i < 3
    ifFalse t0 goto L1
    t1 = i + 1
    i = t1
    goto L0
L1:
```

---

## How to Build & Run

### Prerequisites
- `flex` (Lexer generator)
- `bison` (Parser generator)  
- `gcc` (C compiler)

**Linux/macOS:**
```bash
sudo apt install flex bison gcc   # Ubuntu/Debian
# or
brew install flex bison gcc       # macOS
```

### Build
```bash
make
```

### Run with test file
```bash
./minilang < test_all.txt
```

### Run with your own code
```bash
./minilang < myprogram.ml
```

### Clean build files
```bash
make clean
```

---

## Project Structure

```
minilang/
├── lex.l          — Lexer (tokenizer)
├── yacc.y         — Parser + Symbol Table + TAC Generator
├── Makefile       — Build script
├── test_all.txt   — Test program covering all features
└── README.md      — This file
```

---

## Error Handling

The compiler reports three categories of errors:

| Category | Example |
|---|---|
| Lexical Error | Unknown character `@` |
| Syntax Error  | Missing semicolon `;` |
| Semantic Error | Using undeclared variable `x` |

All errors include the **line number** where they occurred.

---

## Design Decisions

1. **TAC over direct interpretation** — Most student compilers directly evaluate
   expressions. MiniLang generates TAC instead, matching what real compilers do.

2. **Float + Int types** — Two numeric types with a symbol table that tracks
   which type each variable is, demonstrating real type checking.

3. **Label stack for control flow** — `if/else` and `while` use a label stack
   so they can be arbitrarily nested, just like a production compiler.

4. **Error recovery** — The compiler counts all errors and continues parsing
   after a semantic error, so multiple problems are reported at once.
