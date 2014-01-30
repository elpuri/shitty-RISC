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

#include "risccomm.h"
#include <QDebug>
#include <QElapsedTimer>
#include <QCoreApplication>
#include <QStringList>
#include <QFile>

unsigned short takeShort(const QByteArray& d, int& offset) {
    return (unsigned char) d.at(offset++) | (unsigned char) d.at(offset++) << 8;
}

unsigned char takeByte(const QByteArray& d, int& offset) {
    return (unsigned char) d.at(offset++);
}

RiscComm::RiscComm(QObject *parent) :
    QObject(parent)
{
    connect(&m_console, &ConsoleReader::textReceived, this, &RiscComm::onConsoleInput);
}

bool RiscComm::initialize()
{
    m_sp = new QSerialPort();
    m_sp->setPortName("ttyUSB0");
    if (!m_sp->open(QSerialPort::ReadWrite)) {
        qFatal("Couldn't open ttyUSB0");
        return false;
    }
    m_sp->setBaudRate(QSerialPort::Baud115200);
    return true;
}

void RiscComm::onConsoleInput(QString input)
{
    m_sp->readAll();    // flush any residual crap out (from FPGA reset for example)

    if (input.compare("s") == 0) {
        sendStep();
        doScan();
    }
    else if (input.compare("sc") == 0)
        doScan();
    else if (input.compare("q") == 0)
        QCoreApplication::exit();
    else if (input.compare("r") == 0)
        sendRun();
    else if (input.compare("rs") == 0)
        sendReset();
    else if (input.compare("st") == 0) {
        sendStop();
        doScan();
    } else if (input.startsWith("wp")) {
        QStringList args = input.split(" ");
        if (args.length() == 2) {     // upload a file
            sendProgram(args.at(1));
        }
    } else if (input.compare("clrmem") == 0) {
        QByteArray zeros;
        zeros.fill(0, 256);
        writeMem(zeros, 0, true);
    } else if (input.compare("dm") == 0) {
        dumpMem();
    }
    else
        qDebug() << "Unknown command:" << input;
}

void RiscComm::dumpMem()
{
    char readdatacmd[4] = {0x04, 0x02, 0, 0};       // length == 0 implies 256 long read
    m_sp->write(readdatacmd, 4);
    m_sp->flush();

    QByteArray readBytes;
    int length = 256;
    while (length > 0) {
        m_sp->waitForReadyRead(1000);
        QByteArray data = m_sp->readAll();
        if (data.length() == 0) {
            qDebug() << "Dump mem timed out.";
            return;
        }
        readBytes.append(data);
        length -= data.length();
    }

    for (int i = 0; i < 16; i++) {
        for (int j = 0; j < 16; j++) {
            printf("0x%02x ", (unsigned char) readBytes.at(i * 16 + j));
        }
        printf("\n");
    }

}

void RiscComm::sendProgram(QString filename)
{
    QFile program(filename);
    if (!program.open(QFile::ReadOnly)) {
        qDebug() << "Can't open" << filename;
        return;
    }

    QByteArray data = program.readAll();
    writeMem(data, 0, false);
}

void RiscComm::writeMem(QByteArray data, int addr, bool datamem) {
    char writedatacmd[4] = {04, datamem ? 0 : 1, (unsigned char) addr, (unsigned char) data.length() / 2};
    m_sp->write(writedatacmd, 4);
    m_sp->flush();
    m_sp->write(data);
}

void RiscComm::sendStep()
{
    qDebug() << "Sending step command";
    char cmd[4] = {03, 00, 00, 00};
    m_sp->write(cmd, 4);
}

void RiscComm::sendStop()
{
    qDebug() << "Sending stop command";
    char cmd[4] = {00, 00, 00, 00};
    m_sp->write(cmd, 4);
}

void RiscComm::sendRun()
{
    qDebug() << "Sending run command";
    char cmd[4] = {01, 00, 00, 00};
    m_sp->write(cmd, 4);
}

void RiscComm::sendReset()
{
    qDebug() << "Sending reset command";
    char cmd[4] = {05, 00, 00, 00};
    m_sp->write(cmd, 4);
}

void RiscComm::doScan()
{
    qDebug() << "Sending scan command";
    char cmd[4] = {02, 00, 00, 00};
    m_sp->write(cmd, 4);

    //
    // Control path 3 (IR + PC + SR)
    // Regfile 8 (r0 - r3)
    int scanLength = 8 + 2 + 1 + 1;
    QElapsedTimer e;
    e.start();

    QByteArray d;
    while (d.length() < scanLength) {
        m_sp->waitForReadyRead(100);
        if (m_sp->bytesAvailable() > 0)
            d.append(m_sp->readAll());

        if (e.elapsed() > 1000) {
            qDebug() << "Scan timeout. Expecting too many bytes?";
            return;
        }
    }

    unsigned short regs[4];
    unsigned short ir;
    unsigned char pc;
    unsigned char sr;

    int o = 0;
    pc = takeByte(d, o);
    sr = takeByte(d, o);
    ir = takeShort(d, o);
    regs[0] = takeShort(d, o);
    regs[1] = takeShort(d, o);
    regs[2] = takeShort(d, o);
    regs[3] = takeShort(d, o);

    char srString[5];
    srString[0] = sr & 0x8 ? 'H' : '-';
    srString[1] = sr & 0x4 ? 'C' : '-';
    srString[2] = sr & 0x2 ? 'N' : '-';
    srString[3] = sr & 0x1 ? 'Z' : '-';
    srString[4] = 0;
    printf("----------------------------------------------\n");
    printf("R0: 0x%04X  R1: 0x%04X  R2: 0x%04X  R3: 0x%04X\n", regs[0], regs[1], regs[2], regs[3]);
    printf("PC: 0x%02X    SR: --%s  IR: 0x%04X\n", pc, srString, ir);
    printf("----------------------------------------------\n");
}
