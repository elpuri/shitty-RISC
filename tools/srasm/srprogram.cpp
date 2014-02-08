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

#include "srprogram.h"
#include "nodes.h"
#include <assert.h>

// Instruction encoding stuff
#define TARGET_REG 8
#define SRC1_REG 6
#define SRC2_REG 4
#define FLAG_INDIRECT 0x0800
#define FLAG_REGISTER_JUMP_TARGET 0x0800
#define FLAG_EXTEND 0x0400
#define OPCODE_MOVE_IMM 0x1000
#define OPCODE_LOAD 0x2000
#define OPCODE_STORE 0x3000
#define OPCODE_ALUOP 0x4000
#define OPCODE_BRANCH 0x5000
#define OPCODE_COPYDATA 0x6000
#define OPCODE_READ_IO 0xA000   //  essentially LOAD and STORE with MSB set
#define OPCODE_WRITE_IO 0xB000
#define OPCODE_HALT 0xf000
#define OPCODE_NOP 0x0000

SRProgram::SRProgram()
{
}

QByteArray SRProgram::assemble(Section *codeSection, Section *dataSection)
{
    m_dataAllocHead = 0;
    DataSegment firstSeg;
    firstSeg.second = 0;
    m_data.append(firstSeg);

    foreach(Node* n, dataSection->m_nodes) {
        n->visit(this);
    }

    foreach(Node* n, codeSection->m_nodes) {
        n->visit(this);
    }

    for (int i=0; i < m_instructions.length(); i++) {
        QString label = m_codeLabels.key(i);
        if (!label.isEmpty())
            qDebug() << label.append(":");
        qDebug() << "  " << QString::number(m_instructions.at(i), 16);
    }

    int dataCopyInstructionCount = 0;
    foreach(DataSegment s, m_data) {
        // +1 is for loading the segment offset to the pointer register used by COPYDATA
        dataCopyInstructionCount += s.first.length() + 1;
    }

    // All regs are 0 after reset so we don't need to set the pointer for the first segment
    if (dataCopyInstructionCount > 0)
        dataCopyInstructionCount--;

    // Check that all the code and data fits in 256 instructions
    if (dataCopyInstructionCount + m_instructions.length() > 256) {
        qDebug() << "Error: can't fit instructions and data in 256 bytes";
        qDebug() << "Instruction count:" << m_instructions.length() << "Data length:" << dataCopyInstructionCount;
        return QByteArray();
    }

    bool isFirstSeg = true;
    QByteArray bin;
    bin.fill(0, 512);

    int dataPtr = 0;
    // Generate instructions to copy data sections to ram
    foreach (DataSegment seg, m_data) {
        // Generate the instruction to load the segment offset to the pointer register
        if (!isFirstSeg) {
            bin[dataPtr++] = (OPCODE_MOVE_IMM) >> 8;
            bin[dataPtr++] = seg.second;
        }

        for (int i = 0; i < seg.first.length(); i++) {
            bin[dataPtr + i * 2] = (OPCODE_COPYDATA | FLAG_INDIRECT) >> 8;
            bin[dataPtr + i * 2 + 1] = seg.first.at(i);
        }
        dataPtr += seg.first.length() * 2;
        isFirstSeg = false;
    }

    fixCodeLabelReferences(dataPtr / 2);

    foreach(unsigned short instruction, m_instructions) {
        bin[dataPtr++] = (char) (instruction >> 8);
        bin[dataPtr++] = (char) (instruction);
    }

    return bin;
}

int SRProgram::lookupDataLabel(QString label)
{
    int value = m_dataLabels.value(label, -1);
    if (value < 0) {
        qDebug() << "Error: unknown data label" << label;
        qFatal("Terminating assembly");
    }
    return value;
}

bool SRProgram::dataLabelExists(QString label)
{
    return (m_dataLabels.value(label, -1) != -1);
}

void SRProgram::fixCodeLabelReferences(int offset)
{
    foreach(CodeLabelRef ref, m_codeLabelRefs) {
        int address = m_codeLabels.value(ref.second, -1);
        if (address < 0) {
            qDebug() << "Couldn't find code label" << ref.second;
            qFatal("");
        }
        unsigned short instruction = m_instructions.at(ref.first);
        instruction |= (address + offset) & 0xff;
        m_instructions.replace(ref.first, instruction);
    }
}

void SRProgram::handleNode(MoveImmInstruction *n)
{
    //qDebug() << Q_FUNC_INFO << "target reg" << n->targetRegister << "immediate:" << n->immediate << "sign extend:" << n->signExtend;
    unsigned short instruction = OPCODE_MOVE_IMM;
    if (n->label.length() > 0)
        if (dataLabelExists(n->label))
            instruction |= lookupDataLabel(n->label) & 0xff;
        else     // code label, add ref
            m_codeLabelRefs.append(QPair<int, QString>(m_instructions.length(), n->label));
    else
        instruction |= n->immediate;
    if (n->signExtend)
        instruction |= FLAG_EXTEND;
    instruction |= n->targetRegister << TARGET_REG;
    m_instructions.append(instruction);
}

void SRProgram::handleNode(CodeLabel *n)
{
    m_codeLabels.insert(n->name, m_instructions.length());
}

void SRProgram::handleNode(NopInstruction* /* n */)
{
    m_instructions.append(OPCODE_NOP);
}

void SRProgram::handleNode(HaltInstruction* /* n */)
{
    m_instructions.append(OPCODE_HALT);
}

void SRProgram::handleNode(AluInstruction *n)
{
    unsigned short i = OPCODE_ALUOP;
    i |= n->targetRegister << TARGET_REG;
    i |= n->src1Register << SRC1_REG;
    i |= n->src2Register << SRC2_REG;
    switch (n->op) {
        case AluInstruction::Add:
            i |= 0; break;
        case AluInstruction::Sub:
            i |= 1; break;
        case AluInstruction::Zero:
            i |= 4; break;
        case AluInstruction::Swap:
            i |= 5; break;
        case AluInstruction::Not:
            i |= 6; break;
        case AluInstruction::Or:
            i |= 7; break;
        case AluInstruction::And:
            i |= 8; break;
        case AluInstruction::Xor:
            i |= 9; break;
        case AluInstruction::Nop:
            i |= 10; break;
        case AluInstruction::Dec:
            i |= 11; break;
        case AluInstruction::Inc:
            i |= 12; break;
    }
    m_instructions.append(i);
}

void SRProgram::handleNode(BranchInstruction* n)
{
    unsigned short i = OPCODE_BRANCH;
    switch (n->condition) {
        case BranchInstruction::Equal:
            i |= 0x0000; break;
        case BranchInstruction::NotEqual:
            i |= 0x0100; break;
        case BranchInstruction::Always:
            i |= 0x0200; break;
    }
    if (n->label.length() > 0)
        m_codeLabelRefs.append(QPair<int, QString>(m_instructions.length(), n->label));
    else {
        i |= FLAG_REGISTER_JUMP_TARGET;
        i |= n->jumpTargetRegister << SRC1_REG;
    }
    m_instructions.append(i);
}

void SRProgram::handleNode(LoadInstruction *n)
{
    unsigned short i = n->io ? OPCODE_READ_IO : OPCODE_LOAD;
    i |= n->targetRegister << TARGET_REG;
    if (n->signExtend)
        i |= FLAG_EXTEND;

    if (n->indirect) {
        i |= FLAG_INDIRECT;
        i |= n->source << SRC1_REG;
    } else {
        if (n->sourceLabel.length() > 0)
            i |= lookupDataLabel(n->sourceLabel);
        else
            i |= n->source;     // immediate address
    }
    m_instructions.append(i);
}

void SRProgram::handleNode(StoreInstruction *n)
{
    unsigned short i = n->io ? OPCODE_WRITE_IO : OPCODE_STORE;

    // it's really the source reg but due to instruction encoding it's read from the bits where target reg usually is
    i |= n->sourceRegister << TARGET_REG;
    if (n->indirect) {
        i |= FLAG_INDIRECT;
        i |= n->target << SRC1_REG;
    } else {
        if (n->targetLabel.length() > 0)
            i |= lookupDataLabel(n->targetLabel);
        else
            i |= n->target;     // immediate address
    }
    m_instructions.append(i);
}

void SRProgram::handleNode(DataLabel *n)
{
    m_dataLabels.insert(n->name, m_dataAllocHead);
    qDebug() << "Allocated data label" << n->name << "at" << m_dataAllocHead;
}

void SRProgram::handleNode(DataDeclaration *n)
{
    // Store as much data as possible in a single continuous segment until
    // a reserve data declaration breaks the span. m_dataAllocHead tracks what
    // the next free data address is and reserved data can be detected if there's
    // a mismatch between the last data segment offset + length and the head.
    if (m_data.last().second + m_data.last().first.length() != m_dataAllocHead) {
        DataSegment s;
        s.second = m_dataAllocHead;
        m_data.append(s);
    }
    m_data.last().first.append(n->data);
    m_dataAllocHead += n->data.length();
    if (m_dataAllocHead > 255)
        qFatal("Error: data section over allocation");
}

void SRProgram::handleNode(ReserveDataDeclaration *n)
{
    m_dataAllocHead += n->length;
    if (m_dataAllocHead > 255)
        qFatal("Error: data section over allocation");

}
