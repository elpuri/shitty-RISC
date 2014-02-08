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

#ifndef NODES_H
#define NODES_H

#include <QString>
#include <QByteArray>
#include <QList>
#include <QMap>
#include <QDebug>

class SRProgram;

class Node {
public:
    virtual void visit(SRProgram* p) = 0;
};

class Section {
public:
    QList<Node*> m_nodes;
};

class AluInstruction : public Node {
public:
    enum Op { Add, Sub, Zero, And, Or, Xor, Not, Swap, Nop, Dec, Inc };
    void visit(SRProgram *p);

    Op op;
    int targetRegister;
    int src1Register;
    int src2Register;
};

class CodeLabel : public Node {
public:
    void visit(SRProgram* p);
    QString name;
};

class DataLabel : public Node {
public:
    void visit(SRProgram* p);
    QString name;
};

class DataDeclaration : public Node {
public:
    void visit(SRProgram* p);
    QByteArray data;
};

class ReserveDataDeclaration : public Node {
public:
    void visit(SRProgram* p);
    int length;
};

class NopInstruction : public Node {
public:
    void visit(SRProgram* p);
};

class HaltInstruction : public Node {
public:
    void visit(SRProgram* p);
};

class MoveImmInstruction : public Node {
public:
    void visit(SRProgram *p);
    unsigned char immediate;
    QString label;
    int targetRegister;
    bool signExtend;
};

class BranchInstruction : public Node {
public:
    enum Condition { Equal, NotEqual, Always };
    void visit(SRProgram *p);

    Condition condition;
    QString label;
    int jumpTargetRegister;
    bool subroutineCall;
};

class ReturnInstruction : public Node {
public:
    void visit(SRProgram* p);
};

class StackMoveInstruction : public Node {
public:
    void visit(SRProgram* p);
    bool pop;
    int registerName;
    bool extendedReg;   // generate push/pop swap push/pop swap combo to push/pop the whole 16-bit reg
};

class LoadInstruction : public Node {
public:
    void visit(SRProgram *p);
    bool io;
    bool indirect;
    bool signExtend;
    QString sourceLabel;    // source is ignored if sourceLabel is defined
    int source;     // doubles as register or address depending on indirect flag
    int targetRegister;

};

class StoreInstruction : public Node {
public:
    void visit(SRProgram *p);
    bool io;
    bool indirect;
    QString targetLabel;    // target is ignored if targetLabel is defined
    int target;     // doubles as register or address depending on indirect flag
    int sourceRegister;
};


#endif // NODES_H
