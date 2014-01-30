-- Copyright (c) 2014, Juha Turunen
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met: 
--
-- 1. Redistributions of source code must retain the above copyright notice, this
--    list of conditions and the following disclaimer. 
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution. 
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
-- ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity control_path is port (
	clk : in std_logic;
	clk_ena : in std_logic;
	reset : in std_logic;
	
	wr_reg_ena : out std_logic;
	wr_mem_ena : out std_logic;
	
	alu_operation : out std_logic_vector(3 downto 0);
	
	halted : out std_logic;
	
	pgm_mem_addr : out std_logic_vector(7 downto 0);
	pgm_mem_data : in std_logic_vector(15 downto 0);
	
	data_mem_addr : out std_logic_vector(7 downto 0);
	data_mem_in : in std_logic_vector(7 downto 0);
	data_mem_out : out std_logic_vector(15 downto 0);
	
	immediate : out std_logic_vector(7 downto 0);
	
	
	scan_reset : in std_logic;
	scan_input : in std_logic;
	scan_output : out std_logic;
	scan_enable : in std_logic
);
end control_path;

architecture Behavioral of control_path is

subtype operation is std_logic_vector(3 downto 0);
subtype register_address is std_logic_vector(1 downto 0);

signal pc_reg, pc_next : std_logic_vector(7 downto 0);
signal sr_reg, sr_next : std_logic_vector(7 downto 0);

signal op : operation;
signal src1_addr, src2_addr, target_addr : register_address;
signal alu_op : std_logic_vector(3 downto 0);
signal branch_cond : std_logic_vector(1 downto 0);
signal instruction : std_logic_vector(15 downto 0);
signal imm_address, imm_value : std_logic_vector(7 downto 0);

-- status flags
signal carry, carry_next, negative, negative_next, zero, zero_next : std_logic;

-- Instruction | SR | PC
constant scan_length : integer := 16 + 8 + 8; 
signal scan_reg, scan_reg_next : std_logic_vector(scan_length - 1 downto 0);


begin
	process (reset, clk, clk_ena, pc_next, scan_reg_next)
	begin
		if (reset = '1') then
			pc_reg <= (others => '0');
			sr_reg <= (others => '0');
			scan_reg <= (others => '0');
		elsif (clk'event and clk = '1') then
			if (clk_ena = '1') then
				pc_reg <= pc_next;
				sr_reg <= sr_next;
			end if;
			
			scan_reg <= scan_reg_next;
		end if;
	end process;

	-- X = don't care
	-- r = source reg1
	-- s = source reg2
	-- t = target reg
	-- i = immediate value
	-- a = RAM address
	
	-- MOVI 
	--	0000XXttiiiiiiii

	-- MOVR 
	--	0001XXttrrXXXXXX

	-- LD 
	--	0010XXttaaaaaaaa
	
	-- ST 
	-- 0011XXrraaaaaaaa

	-- ADD
	-- 0100XXttrrss0000
	
	-- SUB
	-- 0101XXttrrss0001
	
	-- CLR
	-- 0100XXttXXXX0100
	
	-- SWAP
	-- 0100XXttrrXX0101
	
	-- NOT
	-- 0100XXttrrss0110
	
	-- AND
	-- 0100XXttrrss0111
	
	-- OR
	-- 0100XXttrrss1000
	
	-- XOR
	-- 0100XXttrrss1001
	
	-- TST
	-- 0101XXXXtt001010
	
	-- BREQ
	-- 0110XX00aaaaaaaa
	
	-- BRNE
	-- 0110XX01aaaaaaaa
	
	-- JMP
	-- 0110XX10aaaaaaaa
	
	-- HALT
	-- 0111XXXXXXXXXXXX
	
	-- NOP
	-- 1111XXXXXXXXXXXX
	
	instruction <= pgm_mem_data;
	op <= instruction(15 downto 12);
	target_addr <= instruction(9 downto 8);
	src1_addr <= instruction(7 downto 6);
	src2_addr <= instruction(5 downto 4);
	imm_address <= instruction(7 downto 0);
	imm_value <= instruction(7 downto 0);
	alu_op <= instruction(3 downto 0);
	branch_cond <= instruction(9 downto 8);
	
	
	-- Control path logic
	process (pc_reg)
	begin
		carry_next <= carry;
		negative_next <= negative;
		zero_next <= zero;
		pc_next <= pc_reg + 1;
		wr_reg_ena <= '0';
		wr_mem_ena <= '0';
		
		case op is
			when "0000" =>		-- MOVI
				wr_reg_ena <= '1';
			when others =>
		end case;
				
		
	end process;
	
	-- scan logic
	process (scan_reg, scan_enable, scan_input, scan_reset, pc_reg)
	begin
		if (scan_reset = '1') then
			scan_reg_next <= instruction & sr_reg & pc_reg;
		elsif (scan_enable = '1') then
			scan_reg_next <= scan_input & scan_reg(scan_length - 1 downto 1); 
		else
			scan_reg_next <= scan_reg;
		end if;
	end process;
	
	scan_output <= scan_reg(0);

	-- compose / decompose status register into separate signals
	carry <= sr_reg(0);
	negative <= sr_reg(1);
	zero <= sr_reg(2);
	sr_next <= "00000" & zero_next & negative_next & carry_next;
	
	alu_operation <= alu_op;
	
end Behavioral;