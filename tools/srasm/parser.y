/*
   Copyright (c) 2014, Juha Turunen
   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice, this
      list of conditions and the following disclaimer.
   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
   ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
   WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
   DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
   ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
   (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
   LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
   ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

%{
#include <QtCore>
#include <QDebug>
#include "nodes.h"

extern int yylex(void);
extern int lineNumber;
void yyerror(Section *codeSection, Section *dataSection, const char *s);

void addAluInstruction(Section* section, int t, int r, int s, AluInstruction::Op op)
{
    AluInstruction* n = new AluInstruction;
    n->targetRegister = t;
    n->src1Register = r;
    n->src2Register = s;
    n->op = op;
    section->m_nodes.append(n);
}

void addBranchInstruction(Section* section, BranchInstruction::Condition condition, QString label)
{
    BranchInstruction* n = new BranchInstruction;
    n->label = label;
    n->condition = condition;
    section->m_nodes.append(n);
}

%}

%parse-param {Section *codeSection}
%parse-param {Section *dataSection}

%union {
    QVariant* var;
    QString* str;
    int i;
    QByteArray* data;
}

%token <data> TOK_STRING
%token <i> TOK_INTEGER
%token TOK_COMMA
%token <str> TOK_LABEL
%token <str> TOK_LABEL_REF
%token TOK_ENDL
%token <i> TOK_REGISTER
%token TOK_LPAREN
%token TOK_RPAREN
%token TOK_SOMETHING
%token TOK_SECTION
%token TOK_CODE
%token TOK_DATA
%token TOK_END
%token TOK_DB
%token TOK_RB

// Mnemonics
%token TOK_MOV
%token TOK_NOP
%token TOK_LD
%token TOK_ST
%token TOK_ADD
%token TOK_SUB
%token TOK_CLR
%token TOK_SWAP
%token TOK_NOT
%token TOK_AND
%token TOK_OR
%token TOK_XOR
%token TOK_BREQ
%token TOK_BRNE
%token TOK_BRA
%token TOK_HALT
%token TOK_DEC
%token TOK_INC
%token TOK_OUT
%token TOK_IN

%type <data> data_fragment
%type <data> data
%type <str> label
%type <data> db
%type <i> rb

%destructor {delete $$;} TOK_LABEL
%destructor {delete $$;} TOK_LABEL_REF
%destructor {delete $$;} data
%destructor {delete $$;} data_fragment


%%

start : TOK_SECTION TOK_CODE code_statements TOK_END endls {
    }
      | TOK_SECTION TOK_CODE code_statements TOK_SECTION TOK_DATA data_statements TOK_END endls {
    }


code_statements : code_statements code_statement
                | code_statement

code_statement : label {
    CodeLabel* n = new CodeLabel;
    n->name = *$1;
    codeSection->m_nodes.append(n);
}
              | empty_line
              | mov
              | nop {
    codeSection->m_nodes.append(new NopInstruction);
}
              | ld
              | st
              | swap
              | add
              | sub
              | and
              | or
              | xor
              | not
              | brne
              | breq
              | bra
              | halt
              | dec
              | inc
              | out
              | in

data_statements : data_statements data_statement
                | data_statement

data_statement : label {
    DataLabel* n = new DataLabel;
    n->name = *$1;
    dataSection->m_nodes.append(n);
}
   | empty_line
   | db {
        DataDeclaration* n = new DataDeclaration;
        n->data = *$1;
        dataSection->m_nodes.append(n);
    }
   | rb {
        ReserveDataDeclaration* n = new ReserveDataDeclaration;
        n->length = $1;
        dataSection->m_nodes.append(n);
    }



endls : endls TOK_ENDL
      | TOK_ENDL

label : TOK_LABEL TOK_ENDL

empty_line : TOK_ENDL

// Insructions

mov : TOK_MOV TOK_INTEGER TOK_COMMA TOK_REGISTER TOK_ENDL {
    MoveImmInstruction* n = new MoveImmInstruction();
    n->signExtend = $4 & 0x80000000;
    n->targetRegister = $4 & 0xf;    // mask the sign extend bit
    n->immediate = $2;
    codeSection->m_nodes.append(n);
}
    | TOK_MOV TOK_LABEL_REF TOK_COMMA TOK_REGISTER TOK_ENDL {
            MoveImmInstruction* n = new MoveImmInstruction();
            n->signExtend = $4 & 0x80000000;
            n->targetRegister = $4 & 0xf;    // mask the sign extend bit
            n->label = *$2;
            codeSection->m_nodes.append(n);
    }
     | TOK_MOV TOK_REGISTER TOK_COMMA TOK_REGISTER TOK_ENDL {
     // Reg to reg move is actually a nop alu operation, second operand is don't care
     addAluInstruction(codeSection, $4, $2, $2, AluInstruction::Nop);

}

nop : TOK_NOP TOK_ENDL { qDebug() << "NOP"; }

//  ld $123, r0
ld : TOK_LD TOK_INTEGER TOK_COMMA TOK_REGISTER TOK_ENDL {
        LoadInstruction* n = new LoadInstruction();
        n->indirect = false;
        n->source = $2;
        n->targetRegister = $4;
        n->signExtend = $4 & 0x80000000;
        n->io = false;
        codeSection->m_nodes.append(n);
    }
// ld foo, r0
   | TOK_LD TOK_LABEL_REF TOK_COMMA TOK_REGISTER TOK_ENDL {
       LoadInstruction* n = new LoadInstruction();
       n->indirect = false;
       n->sourceLabel = *$2;
       n->targetRegister = $4;
       n->signExtend = $4 & 0x80000000;
       n->io = false;
       codeSection->m_nodes.append(n);
    }
// ld (r1), r0
   | TOK_LD TOK_LPAREN TOK_REGISTER TOK_RPAREN TOK_COMMA TOK_REGISTER TOK_ENDL {
       LoadInstruction* n = new LoadInstruction();
       n->indirect = true;
       n->source = $3;
       n->targetRegister = $6;
       n->signExtend = $6 & 0x80000000;
       n->io = false;
       codeSection->m_nodes.append(n);
    }

in : TOK_IN TOK_INTEGER TOK_COMMA TOK_REGISTER TOK_ENDL {
        LoadInstruction* n = new LoadInstruction();
        n->indirect = false;
        n->source = $2;
        n->targetRegister = $4;
        n->signExtend = $4 & 0x80000000;
        n->io = true;
        codeSection->m_nodes.append(n);
    }
   | TOK_IN TOK_LPAREN TOK_REGISTER TOK_RPAREN TOK_COMMA TOK_REGISTER TOK_ENDL {
       LoadInstruction* n = new LoadInstruction();
       n->indirect = true;
       n->source = $3;
       n->targetRegister = $6;
       n->signExtend = $6 & 0x80000000;
       n->io = true;
       codeSection->m_nodes.append(n);
    }


st : TOK_ST TOK_REGISTER TOK_COMMA TOK_INTEGER TOK_ENDL {
        StoreInstruction* n = new StoreInstruction();
        n->indirect = false;
        n->target = $4;
        n->sourceRegister = $2;
        n->io = false;
        codeSection->m_nodes.append(n);
    }
   | TOK_ST TOK_REGISTER TOK_COMMA TOK_LABEL_REF TOK_ENDL {
       StoreInstruction* n = new StoreInstruction();
       n->indirect = false;
       n->targetLabel = *$4;
       n->sourceRegister = $2;
       n->io = false;
       codeSection->m_nodes.append(n);
}
   | TOK_ST TOK_REGISTER TOK_COMMA TOK_LPAREN TOK_REGISTER TOK_RPAREN TOK_ENDL {
        StoreInstruction* n = new StoreInstruction();
        n->indirect = true;
        n->target = $5;
        n->sourceRegister = $2;
        n->io = false;
        codeSection->m_nodes.append(n);
}

out : TOK_OUT TOK_REGISTER TOK_COMMA TOK_INTEGER TOK_ENDL {
        StoreInstruction* n = new StoreInstruction();
        n->indirect = false;
        n->target = $4;
        n->sourceRegister = $2;
        n->io = true;
        codeSection->m_nodes.append(n);
    }
   | TOK_OUT TOK_REGISTER TOK_COMMA TOK_LPAREN TOK_REGISTER TOK_RPAREN TOK_ENDL {
        StoreInstruction* n = new StoreInstruction();
        n->indirect = true;
        n->target = $5;
        n->sourceRegister = $2;
        n->io = true;
        codeSection->m_nodes.append(n);
}

add : TOK_ADD TOK_REGISTER TOK_COMMA TOK_REGISTER TOK_COMMA TOK_REGISTER TOK_ENDL {
        addAluInstruction(codeSection, $6, $2, $4, AluInstruction::Add);
    }

sub : TOK_SUB TOK_REGISTER TOK_COMMA TOK_REGISTER TOK_COMMA TOK_REGISTER TOK_ENDL {
        addAluInstruction(codeSection, $6, $2, $4, AluInstruction::Sub);
    }

and : TOK_AND TOK_REGISTER TOK_COMMA TOK_REGISTER TOK_COMMA TOK_REGISTER TOK_ENDL {
        addAluInstruction(codeSection, $6, $2, $4, AluInstruction::And);
    }

or : TOK_OR TOK_REGISTER TOK_COMMA TOK_REGISTER TOK_COMMA TOK_REGISTER TOK_ENDL {
        addAluInstruction(codeSection, $6, $2, $4, AluInstruction::Or);
    }

xor : TOK_XOR TOK_REGISTER TOK_COMMA TOK_REGISTER TOK_COMMA TOK_REGISTER TOK_ENDL {
        addAluInstruction(codeSection, $6, $2, $4, AluInstruction::Xor);
    }

swap : TOK_SWAP TOK_REGISTER TOK_COMMA TOK_REGISTER TOK_ENDL {
        addAluInstruction(codeSection, $4, $2, $2, AluInstruction::Swap);
    }
    | TOK_SWAP TOK_REGISTER TOK_ENDL {
        addAluInstruction(codeSection, $2, $2, $2, AluInstruction::Swap);
    }

not : TOK_NOT TOK_REGISTER TOK_COMMA TOK_REGISTER TOK_ENDL {
        addAluInstruction(codeSection, $4, $2, $2, AluInstruction::Not);
    }

dec : TOK_DEC TOK_REGISTER TOK_ENDL {
        addAluInstruction(codeSection, $2, $2, $2, AluInstruction::Dec);
    }
    | TOK_DEC TOK_REGISTER TOK_COMMA TOK_REGISTER {
        addAluInstruction(codeSection, $4, $2, $2, AluInstruction::Dec);
    }

inc : TOK_INC TOK_REGISTER TOK_ENDL {
        addAluInstruction(codeSection, $2, $2, $2, AluInstruction::Inc);
    }
    | TOK_INC TOK_REGISTER TOK_COMMA TOK_REGISTER {
        addAluInstruction(codeSection, $4, $2, $2, AluInstruction::Inc);
    }

brne : TOK_BRNE TOK_LABEL_REF TOK_ENDL {
        addBranchInstruction(codeSection, BranchInstruction::NotEqual, *$2);
    }

breq : TOK_BREQ TOK_LABEL_REF TOK_ENDL {
        addBranchInstruction(codeSection, BranchInstruction::Equal, *$2);
    }

bra : TOK_BRA TOK_LABEL_REF TOK_ENDL {
        addBranchInstruction(codeSection, BranchInstruction::Always, *$2);
    }

halt : TOK_HALT TOK_ENDL {
        codeSection->m_nodes.append(new HaltInstruction);
    }

db : TOK_DB data TOK_ENDL {
    $$ = new QByteArray(*$2);
}

rb : TOK_RB TOK_INTEGER TOK_ENDL {
    $$ = $2;
}

data : data TOK_COMMA data_fragment {
        $$ = new QByteArray(*$1);
        $$->append(*$3);
    }
     | data_fragment {
        $$ = new QByteArray(*$1);
    }

data_fragment  : TOK_STRING {
    $$ = new QByteArray(*$1);
}
               | TOK_INTEGER {
    if ($1 > 255)
        YYERROR;
    $$ = new QByteArray();
    $$->append($1);
}
%%

void yyerror(Section* codeSection, Section* dataSection, const char* s) {
    qDebug() << "Error on line" << lineNumber << ":" << s;
}
