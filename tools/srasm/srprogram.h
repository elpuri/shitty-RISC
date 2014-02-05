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

#ifndef SRPROGRAM_H
#define SRPROGRAM_H

#include <QMap>
#include <QString>
#include <QPair>

class CodeLabel;
class DataLabel;
class ReserveDataDeclaration;
class DataDeclaration;
class Section;
class NopInstruction;
class MoveImmInstruction;
class MoveRegisterInstruction;
class HaltInstruction;
class AluInstruction;
class BranchInstruction;
class StoreInstruction;
class LoadInstruction;

class SRProgram
{
public:
    SRProgram();

    typedef QPair<int, QString> CodeLabelRef;
    typedef QPair<QByteArray, int> DataSegment;

    QByteArray assemble(Section* codeSection, Section* dataSection);

    void handleNode(CodeLabel*);
    void handleNode(DataLabel*);
    void handleNode(DataDeclaration*);
    void handleNode(ReserveDataDeclaration*);
    void handleNode(NopInstruction*);
    void handleNode(MoveImmInstruction*);
    void handleNode(MoveRegisterInstruction*);
    void handleNode(HaltInstruction*);
    void handleNode(AluInstruction*);
    void handleNode(BranchInstruction*);
    void handleNode(LoadInstruction*);
    void handleNode(StoreInstruction*);

private:
    void fixCodeLabelReferences(int offset);
    int lookupDataLabel(QString label);
    bool dataLabelExists(QString label);
    int dataAllocHead();

private:
    QMap<QString, int> m_codeLabels;
    QMap<QString, int> m_dataLabels;
    QList<CodeLabelRef> m_codeLabelRefs;

    QList<DataSegment> m_data;
    int m_dataAllocHead;
    QList<unsigned short> m_instructions;
};

#endif // SRPROGRAM_H
