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
#include "parser.h"
int lineNumber = 1;
%}


%x COMMENT

%%

, return TOK_COMMA;
\( return TOK_LPAREN;
\) return TOK_RPAREN;


SECTION     { return TOK_SECTION; }
CODE        { return TOK_CODE; }
DATA        { return TOK_DATA; }
END         { return TOK_END; }
(DB)|(db)   { return TOK_DB; }
(RB)|(rb)   { return TOK_RB; }

(MOV)|(mov)    { return TOK_MOV; }
(NOP)|(nop)     { return TOK_NOP; }
(LD)|(ld)      { return TOK_LD; }
(ST)|(st)      { return TOK_ST; }
(ADD)|(add)     { return TOK_ADD; }
(SUB)|(sub)     { return TOK_SUB; }
(CLR)|(clr)     { return TOK_CLR; }
(SWAP)|(swap)    { return TOK_SWAP; }
(NOT)|(not)     { return TOK_NOT; }
(AND)|(and)     { return TOK_AND; }
(OR)|(or)      { return TOK_OR; }
(XOR)|(xor)     { return TOK_XOR; }
(BREQ)|(breq)    { return TOK_BREQ; }
(BRNE)|(brne)    { return TOK_BRNE; }
(BRA)|(bra)     { return TOK_BRA; }
(HALT)|(halt)    { return TOK_HALT; }
(DEC)|(dec)     { return TOK_DEC; }
(INC)|(inc)     { return TOK_INC; }
(IN)|(in)       { return TOK_IN; }
(OUT)|(out)     { return TOK_OUT; }

[a-zA-Z_][a-z0-9_]*: {
//    qDebug() << "Lexer found label" << yytext;
    QString l = QString::fromLatin1( yytext, yyleng - 1);
    yylval.str = new QString(l);
    return TOK_LABEL;
}


-?[0-9]+ {
    yylval.i = QString(yytext).toInt();
    return TOK_INTEGER;
}

-?$[0-9a-fA-F]+ {
    // Hex integer
    QString n(yytext);
    bool ok;
    yylval.i = n.startsWith("-") ? -n.right(n.length() - 2).toInt(&ok, 16) :
                                   n.right(n.length() - 1).toInt(&ok, 16);
    return TOK_INTEGER;
}

\"(\\.|[^\\"])*\" {
    yylval.data = new QByteArray(yytext + 1, yyleng - 2);   // strip the quotes
    return TOK_STRING;
}

[ \t] ;

r[0123]e? {
    QString s(yytext);
    yylval.i = s.mid(1, 1).toInt();
    if (s.endsWith("e"))
        yylval.i |= 0x80000000;     // MSB indicates we want to sign extend and access all 16 bits of the register
    return TOK_REGISTER;
}


[a-zA-Z_][a-z0-9_]* {
    yylval.str = new QString(yytext);
    return TOK_LABEL_REF;
}


\n      {
     //qDebug() << "Found endline token";
     lineNumber++;
     return TOK_ENDL;
}

\/\/            { BEGIN(COMMENT); }
<COMMENT>\n     { BEGIN(INITIAL); ++lineNumber; return TOK_ENDL; }
<COMMENT>.  ;

.  {return TOK_SOMETHING; }



%%
