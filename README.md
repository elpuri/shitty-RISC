shitty-RISC
===========

Shitty-RISC is a totally ghetto RISC CPU with peripherals written in VHDL and Qt based assembler and debugging tools. The top level entity is written for a totally ghetto chinese Altera Cyclone I based FPGA development board, but in the unlikely case of somebody being actually interested in running this, it should be easy to port to almost any board or FPGA.

CPU features
------------
* Single cycle instructions
* Harvard architecture (separate program and data memory)
* Four (4!) 16-bit general purpose registers
* 8-bit address and data busses

Project features
----------------
* JTAG style debug chain for probing internal state of various parts of the design during operation
* A remote controllable debugger module that's responsible of communication with the debug console running on the PC, producing the clock enable signal for the CPU and reading and writing the program and data memories.  
* A "display device" controlling four multiplexed seven segment displays. Controlled by four data registers (one for each display) and a control register for turning them on/off and selecting mode of operation (encoded or direct control of individual segments)
* A beeper device capable of producing 32 different notes on the piezo buzzer of the development board
* An HD44780 driver logic for operating an LCD display. For now the driver is write only because whoever designed the EP1 board had the great idea of providing 5V to the HD44780 header. Letting the HD44780 drive the I/O pins of the FPGA running @3.3V would fry the inputs. 

TODO
----

* A stack pointer and associated instuctions (push, pop, jump to subroutine)
* Add/sub with carry
* Test/compare instructions that perform ALU operations which affect status flags, but don't write the actual result anywhere
* Small Qt based IDE with syntax highlighting, symbol completion etc.
* Disassembly of current instruction in the debugger
* Interrupts
* Hardware breakpoint(s)
