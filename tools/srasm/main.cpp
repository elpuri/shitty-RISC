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

#include <QCoreApplication>
#include <QFile>
#include <QDebug>
#include <QStringList>

#include "lexer.h"
#include "nodes.h"
#include "parser.h"
#include "srprogram.h"

int yyparse(Section*, Section*);
extern QVariant* root;

int main(int argc, char *argv[])
{
    QCoreApplication a(argc, argv);
    if (argc < 2)
        qDebug() << "Usage: <sourcefile> [outputfile]";

    QFile source(a.arguments().at(1));
    if (!source.open(QFile::ReadOnly)) {
        qDebug() << "Couldn't open source file" << a.arguments().at(1);
        return 0;
    }

    QByteArray data = source.readAll();

    YY_BUFFER_STATE bufferState = yy_scan_string(data.constData());

    Section codeSection;
    Section dataSection;

    // Parse the string.
    yyparse(&codeSection, &dataSection);

    // flush the input stream.
    yy_delete_buffer(bufferState);

    SRProgram prg;
    QByteArray bin = prg.assemble(&codeSection, &dataSection);

    QString outputFilename;
    if (argc < 3)
        outputFilename = a.arguments().at(1).split(".").first().append(".bin");
      else
        outputFilename = a.arguments().at(2);

    QFile output(outputFilename);
    if (!output.open(QFile::WriteOnly)) {
        qDebug() << "Can't open outputfile" << outputFilename;
    }

    qDebug() << "Wrote binary to" << outputFilename;
    output.write(bin);
}
