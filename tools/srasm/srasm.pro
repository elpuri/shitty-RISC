QT       += core
QT       -= gui

TARGET = srasm
CONFIG   += console
CONFIG   -= app_bundle

TEMPLATE = app

QMAKE_CXXFLAGS = -std=c++0x

HEADERS += nodes.h \
    srprogram.h
SOURCES += main.cpp \
    nodes.cpp \
    srprogram.cpp

# Flex and bison stuff shamelessly ripped from http://hipersayanx.blogspot.com/2013/03/using-flex-and-bison-with-qt.html
LIBS += -lfl -ly
FLEXSOURCES = lexer.l
BISONSOURCES = parser.y

OTHER_FILES +=  \
    $$FLEXSOURCES \
    $$BISONSOURCES \
    lexer.l \
    parser.y \
    tests/count.asm \
    tests/fibonacci.asm \
    tests/cpydata.asm \
    tests/display.asm \
    tests/beeper.asm \
    tests/subroutine.asm

flexsource.input = FLEXSOURCES
flexsource.output = ${QMAKE_FILE_BASE}.cpp
flexsource.commands = flex --header-file=${QMAKE_FILE_BASE}.h -o ${QMAKE_FILE_BASE}.cpp ${QMAKE_FILE_IN}
flexsource.variable_out = SOURCES
flexsource.name = Flex Sources ${QMAKE_FILE_IN}
flexsource.CONFIG += target_predeps

QMAKE_EXTRA_COMPILERS += flexsource

flexheader.input = FLEXSOURCES
flexheader.output = ${QMAKE_FILE_BASE}.h
flexheader.commands = @true
flexheader.variable_out = HEADERS
flexheader.name = Flex Headers ${QMAKE_FILE_IN}
flexheader.CONFIG += target_predeps no_link

QMAKE_EXTRA_COMPILERS += flexheader

bisonsource.input = BISONSOURCES
bisonsource.output = ${QMAKE_FILE_BASE}.cpp
bisonsource.commands = bison -d --verbose --defines=${QMAKE_FILE_BASE}.h -o ${QMAKE_FILE_BASE}.cpp ${QMAKE_FILE_IN}
bisonsource.variable_out = SOURCES
bisonsource.name = Bison Sources ${QMAKE_FILE_IN}
bisonsource.CONFIG += target_predeps

QMAKE_EXTRA_COMPILERS += bisonsource

bisonheader.input = BISONSOURCES
bisonheader.output = ${QMAKE_FILE_BASE}.h
bisonheader.commands = @true
bisonheader.variable_out = HEADERS
bisonheader.name = Bison Headers ${QMAKE_FILE_IN}
bisonheader.CONFIG += target_predeps no_link

QMAKE_EXTRA_COMPILERS += bisonheader

HEADERS += \
    nodes.h
