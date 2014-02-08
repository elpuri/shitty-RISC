shitty-RISC
===========

Shitty-RISC is a totally ghetto RISC CPU with peripherals written in VHDL and Qt based assembler and debugging tools. The top level entity is written for a totally ghetto chinese Altera Cyclone I based FPGA development board, but in the unlikely case of somebody being actually interested in running this, it should be easy to port to almost any board or FPGA.

CPU features
------------
* Single cycle instructions
* Harvard architecture (separate program and data memory)
* Fixed width 16-bit instructions
* Four (4!) 16-bit general purpose registers
* Stack pointer
* 8-bit address and data busses

Project features
----------------
* JTAG style debug chain for probing internal state of various parts of the design during operation
* A remote controllable debugger module that's responsible of communication with the debug console running on the PC, producing the clock enable signal for the CPU and reading and writing the program and data memories.  
* A "display device" controlling four multiplexed seven segment displays. Controlled by four data registers (one for each display) and a control register for turning them on/off and selecting mode of operation (encoded or direct control of individual segments)
* A beeper device capable of producing 32 different notes on the piezo buzzer of the development board
* An HD44780 driver logic for operating an LCD display. For now the driver is write only because whoever designed the EP1 board had the great idea of providing 5V to the HD44780 header. Letting the HD44780 drive the I/O pins of the FPGA running @3.3V would fry the inputs. 

Instruction set
---------------

<pre><code>

X = don't care

Instruction:      No operation
Mnemonic(s):      NOP
Description:      No operation
Instruction word: 0000XXXXXXXXXXXX

Instruction:      Move immediate
Mnemonic(s):      MOV imm, rr[e]
Descritipon:      Writes the immediate value to the target register
Instruction word: 0001Xerriiiiiiii
                  e = 0 - write only lower byte of the target register
                  e = 1 - write both bytes of the register, fill upper byte with MSB of the immediate value
                  rr = target register number (0-3)
                  i = immediate value bits
                  
Instruction:      Load memory immediate
Mnemonic(s):      LD (imm), rr[e]
Operation:        Loads a byte from immediate address and places it into the target register
Instruction word: 00100erriiiiiiii
                  e = 0 - write only lower byte of the target register
                  e = 1 - write both bytes of the register, fill upper byte with MSB of the immediate value
                  rr = target register number (0-3)
                  i = immediate value bits
                  
Instruction:      Load memory indirect
Mnemonic(s):      LD (ss), rr[e]
Operation:        Loads a byte from a memory address pointed by a register and places it into the target register
Instruction word: 00101errssXXXXXX
                  e = 0 - write only lower byte of the target register
                  e = 1 - write both bytes of the register, fill upper byte with MSB of the immediate value
                  rr = target register number (0-3)
                  ss = address register number (0-3)

Instruction:      Store memory immediate
Mnemonic(s):      ST rr, (imm)
Operation:        Stores a byte from a register to an immediate memory address
Instruction word: 001100rriiiiiiii
                  rr = source register number (0-3)
                  i = immediate value bits

Instruction:      Store memory indirect
Mnemonic(s):      ST rr, (ss)
Operation:        Stores a byte from a register to a memory address pointed by a register
Instruction word: 001110rrssXXXXXX
                  rr = source register number (0-3)
                  ss = address register number (0-3)

Instruction:      Move register
Mnemonic(s):      MOV rr, ss
Operation:        Moves a register to another register. This is essentially an ALU instruction 
                  with a null operation.
Instruction word: 0100XXssrrXX1010
                  rr = source register number (0-3)
                  ss = target register number (0-3)
                  
Instruction:      Add registers
Mnemonic(s):      ADD rr, ss, tt
Operation:        Adds two registers and writes the result to a register 
Instruction word: 0100XXttrrss0000
                  rr = source register number (0-3)
                  ss = source register number (0-3)
                  tt = target register number (0-3)

Instruction:      Subtract registers
Mnemonic(s):      ADD rr, ss, tt
Operation:        Substracts two registers (rr - ss) and writes the result to a register. 
Instruction word: 0100XXttrrss0000
                  rr = source register number (0-3)
                  ss = source register number (0-3)
                  tt = target register number (0-3)

Instruction:      Swap register halves
Mnemonic(s):      SWAP rr, ss
                  SWAP ss
Operation:        Swaps the upper and lower bytes of a register and stores the result to a register.
                  The single operand variant is simply assembler sugar.
Instruction word: 0100XXssrrXX0101
                  rr = source register number (0-3)
                  ss = target register number (0-3)

Instruction:      Negate register
Mnemonic(s):      NOT rr, ss
                  NOT ss
Operation:        Negates the bits of a register and stores the result to a register.
                  The single operand variant is simply assembler sugar.
Instruction word: 0100XXssrrXX0110
                  rr = source register number (0-3)
                  ss = target register number (0-3)
                  
Instruction:      Logical AND operation
Mnemonic(s):      AND rr, ss, tt
Operation:        Performs a logical AND operation on two registers and writes the result to a register 
Instruction word: 0100XXttrrss0111
                  rr = source register number (0-3)
                  ss = source register number (0-3)
                  tt = target register number (0-3)
                  
Instruction:      Logical OR operation
Mnemonic(s):      OR rr, ss, tt
Operation:        Performs a logical OR operation on two registers and writes the result to a register 
Instruction word: 0100XXttrrss1000
                  rr = source register number (0-3)
                  ss = source register number (0-3)
                  tt = target register number (0-3)
                  
Instruction:      Logical XOR operation
Mnemonic(s):      XOR rr, ss, tt
Operation:        Performs a logical XOR operation on two registers and writes the result to a register 
Instruction word: 0100XXttrrss1001
                  rr = source register number (0-3)
                  ss = source register number (0-3)
                  tt = target register number (0-3)

Instruction:      Increment register
Mnemonic(s):      INC rr, ss
                  INC ss
Operation:        Increments a register by 1 and stores the result to a register.
                  The single operand variant is simply assembler sugar.
Instruction word: 0100XXssrrXX1100
                  rr = source register number (0-3)
                  ss = target register number (0-3)

Instruction:      Decrement register
Mnemonic(s):      INC rr, ss
                  INC ss
Operation:        Decrements a register by 1 and stores the result to a register.
                  The single operand variant is simply assembler sugar.
Instruction word: 0100XXssrrXX1011
                  rr = source register number (0-3)
                  ss = target register number (0-3)

                  
</code></pre>

I/O map
------
<pre><code>
$00-$04 - 7-segment display write-only data registers. Encoded or coded depending on control register.
$05     - 7-segment display control register. XXXXXXCE
          C = 1, interpret the four LSBs of the data register as a hex digit
          C = 0, each data register bit drives individual segement
          E, 1 = display on, 0 = display off.
$10     - Beeper device write-only frequency register. 
          Values 0-31 correspond to two octaves of musical notes.
          0xFF = silence
$20     - Write LCD command. Write-only.
$21     - Write LCD data RAM. Write-only.
          
</code></pre>


TODO
----

* A stack pointer and associated instuctions (push, pop, jump to subroutine) - **DONE**
* Add/sub with carry
* Test/compare instructions that perform ALU operations which affect status flags, but don't write the actual result anywhere
* Small Qt based IDE with syntax highlighting, symbol completion etc.
* Disassembly of current instruction in the debugger
* Interrupts
* Hardware breakpoint(s)

