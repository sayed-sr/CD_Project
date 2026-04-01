# MiniLang Compiler — Makefile
# Works on Linux/macOS with flex + bison + gcc installed
# On Windows: use WSL or MinGW

CC      = gcc
CFLAGS  = -Wall -Wextra -g
TARGET  = minilang

all: $(TARGET)

$(TARGET): yacc.tab.c lex.yy.c
	$(CC) $(CFLAGS) -o $(TARGET) yacc.tab.c lex.yy.c -lfl

yacc.tab.c yacc.tab.h: yacc.y
	bison -d -o yacc.tab.c yacc.y

lex.yy.c: lex.l yacc.tab.h
	flex -o lex.yy.c lex.l

clean:
	rm -f $(TARGET) yacc.tab.c yacc.tab.h lex.yy.c *.o

run: $(TARGET)
	./$(TARGET) < test_all.txt

.PHONY: all clean run
