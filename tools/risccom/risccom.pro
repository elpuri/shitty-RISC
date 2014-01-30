QT       += core serialport
QT       -= gui

TARGET = risccom
CONFIG   += console
CONFIG   -= app_bundle

TEMPLATE = app


SOURCES += main.cpp \
    consolereader.cpp \
    risccomm.cpp

HEADERS += \
    consolereader.h \
    risccomm.h

OTHER_FILES += \
    asd.txt
