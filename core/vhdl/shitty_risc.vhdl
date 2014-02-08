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


entity shitty_risc is port (
	clk : in std_logic;
	reset : in std_logic;
	clk_ena : in std_logic;
	halt : out std_logic;
	
	scan_reset : in std_logic;
	scan_input : in std_logic;
	scan_output : out std_logic;
	scan_enable : in std_logic;
	
	pgm_mem_addr : out std_logic_vector(7 downto 0);
	pgm_mem_data_in : in std_logic_vector(15 downto 0);
	
	data_mem_addr : out std_logic_vector(7 downto 0);
	data_mem_data_in : in std_logic_vector(7 downto 0);
	data_mem_data_out : out std_logic_vector(7 downto 0);
	data_mem_wr_ena : out std_logic;
	mem_io_select : out std_logic
);
end shitty_risc;

architecture Behavioral of shitty_risc is

subtype operation is std_logic_vector(3 downto 0);
subtype register_address is std_logic_vector(1 downto 0);

signal reg_file_scan_input, reg_file_scan_output : std_logic;
signal reg_wr_ena : std_logic;
signal reg_src1_out, reg_src2_out, reg_dst_in, reg_dst_out : std_logic_vector(15 downto 0);

signal alu_op : std_logic_vector(3 downto 0);
signal alu_src1 : std_logic_vector(15 downto 0);
signal alu_src2 : std_logic_vector(15 downto 0);
signal alu_result : std_logic_vector(15 downto 0);
signal alu_carry_in, alu_carry_out, alu_zero, alu_negative : std_logic;

signal control_path_scan_input, control_path_scan_output : std_logic;

signal pc_reg, pc_next : std_logic_vector(7 downto 0);
signal sr_reg, sr_next : std_logic_vector(7 downto 0);
signal sp_reg, sp_next : std_logic_vector(7 downto 0) := "11111111";

-- Instruction decoding related
signal op : operation;
signal op_alu_op : std_logic_vector(3 downto 0);
signal op_sign_extend, op_indirect_addr, op_register_jump_target : std_logic;
signal op_pop_push : std_logic;
signal reg_src1_select, reg_src2_select, reg_dst_select : register_address;
signal branch_cond : std_logic_vector(1 downto 0);
signal instruction : std_logic_vector(15 downto 0);
signal imm_address, imm_value : std_logic_vector(7 downto 0);
signal jump_target : std_logic_vector(7 downto 0);

-- status flags
signal carry, carry_next, negative, negative_next, zero, zero_next, halted, halted_next : std_logic;

-- Instruction | SR | PC
constant scan_length : integer := 16 + 8 + 8 + 8; 
signal scan_reg, scan_reg_next : std_logic_vector(scan_length - 1 downto 0);

signal movi_high_byte, ld_high_byte : std_logic_vector(7 downto 0);

signal mem_write: std_logic;

signal stack_read_access, stack_write_access : std_logic;


begin

	process (reset, clk, clk_ena)
	begin
		if (reset = '1') then
			pc_reg <= (others => '0');
			sr_reg <= (others => '0');
			scan_reg <= (others => '0');
			sp_reg <= "11111111";
		elsif (clk'event and clk = '1') then			
			if (clk_ena = '1') then
				pc_reg <= pc_next;
				sr_reg <= sr_next;
				sp_reg <= sp_next;
			end if;
			-- not related to actual CPU functionality so no need to depend on clk_ena
			scan_reg <= scan_reg_next;
		end if;
	end process;

	-- General purpose registers
	registers : entity work.register_file port map (
		clk => clk,
		clk_ena => clk_ena,
		scan_reset => scan_reset,
		scan_input => reg_file_scan_input,
		scan_output => reg_file_scan_output,
		scan_enable => scan_enable,
		reset => reset,
		dst_wr_ena => reg_wr_ena,
		src1_select => reg_src1_select,
		src1_out => reg_src1_out,
		src2_select => reg_src2_select,
		src2_out => reg_src2_out,
		dst_select => reg_dst_select,
		dst_in => reg_dst_in,
		dst_out => reg_dst_out
	);
			
	alu : entity work.alu port map (
		op => alu_op,
		src1 => alu_src1,
		src2 => alu_src2,
		result => alu_result,
		carry_in => alu_carry_in,
		zero => alu_zero,
		negative => alu_negative
	);
	
	alu_src1 <= reg_src1_out;
	alu_src2 <= reg_src2_out;
	alu_carry_in <= carry;

	halt <= halted;
	
	-- X = don't care
	-- r = source reg1
	-- s = source reg2
	-- t = target reg
	-- i = immediate value
	-- a = RAM address
	-- e = sign extend flag
	-- n = indirect addressing
	-- R = register jump target
	-- o = IO write
	
	-- NOP
	-- 0000XXXXXXXXXXXX

	-- MOVI 
	--	0001Xettiiiiiiii

	-- LD 
	--	0010Xettaaaaaaaa
	-- t = (imm)
	
	-- LDI
	--	0010nettrrXXXXXX
	-- t = (r)
	
	-- ST 
	-- 00110ottaaaaaaaa
	-- (imm) = t
	
	-- STI
	-- 0011nXttrrXXXXXX
	-- (r) = t
	
	-- ADD
	-- 0100XXttrrss0000
	-- t = r + s
	
	-- MOVR 
	--	0100XXttrrXX1010
	-- t = r
	
	-- SUB
	-- 0100XXttrrss0001
	-- t = r - s
	
	-- CLR
	-- 0100XXttXXXX0100
	-- t = 0
	
	-- SWAP
	-- 0100XXttrrXX0101
	-- t = swap_hi_lo(r)
	
	-- NOT
	-- 0100XXttrrXX0110
	-- t = !r
	
	-- AND
	-- 0100XXttrrss0111
	-- t = r & t
	
	-- OR
	-- 0100XXttrrss1000
	-- t = r | t
	
	-- XOR
	-- 0100XXttrrss1001
	-- t = r ^ t
	
	-- DEC
	-- 0100XXttrrXX1011
	-- t = r - 1
	
	-- BREQ
	-- 0101XX00aaaaaaaa
	
	-- BREQI	(others follow same pattern regarding I)
	-- 0101RX00rrXXXXXX
	
	-- BRNE
	-- 0101XX01aaaaaaaa
	
	-- BRA
	-- 0101XX10aaaaaaaa
	
	-- BSR
	--	0111XX10aaaaaaaa
	
	-- BSRE
	--	0111XX00aaaaaaaa
	
	-- BSRNE
	--	0111XX01aaaaaaaa
	
	-- RET
	--	1000XXXXXXXXXXXX
	
	-- PUSH
	-- 10010XttXXXXXXXX

	-- POP
	-- 10011XttXXXXXXXX
	
	-- CPYDATA
	--	01101Xttiiiiiiii
	-- (t++) = imm
	
	-- HALT
	-- 1111XXXXXXXXXXXX
	
	
	
	instruction <= pgm_mem_data_in;
	op <= instruction(15 downto 12);
	reg_dst_select <= instruction(9 downto 8);
	reg_src2_select <= instruction(5 downto 4);
	imm_address <= instruction(7 downto 0);
	imm_value <= instruction(7 downto 0);
	op_alu_op <= instruction(3 downto 0);
	branch_cond <= instruction(9 downto 8);
	op_sign_extend <= instruction(10);
	op_indirect_addr <= instruction(11);
	op_register_jump_target <= instruction(11);
	op_pop_push <= instruction(11);
	
	-- Separate status flags
	halted <= sr_reg(3);
	carry <= sr_reg(2);
	negative <= sr_reg(1);
	zero <= sr_reg(0);

	
	-- Control path logic
	process (pc_reg, carry, negative, zero, sr_reg, sp_reg, imm_value, op_sign_extend, data_mem_data_in,
				op, movi_high_byte, alu_result, ld_high_byte, branch_cond, imm_address,
				alu_zero, alu_negative, reg_dst_out, zero_next)
	begin
		halted_next <= halted;
		carry_next <= carry;
		negative_next <= negative;
		zero_next <= zero;
		reg_wr_ena <= '0';
		mem_write <= '0';
		reg_dst_in <= (others => 'X');
		alu_op <= op_alu_op;
		reg_src1_select <= instruction(7 downto 6);
		mem_io_select <= '1';
		stack_read_access <= '0';
		stack_write_access <= '0';
		sp_next <= sp_reg;
		

		sr_next <= "0000" & halted_next & carry_next & negative_next & zero_next;
		pc_next <= pc_reg + 1;

		-- to simplify encoding we're using the usual dest reg as output for st instruction
		data_mem_data_out <= reg_dst_out(7 downto 0);		
		
		-- generate high bytes for movi and ld with sign extension if op_sign_extend is set
		for i in 0 to 7 loop
			movi_high_byte(i) <= imm_value(7);
			ld_high_byte(i) <= data_mem_data_in(7);
		end loop;
		
		case op is
			when "0000" =>		-- NOP
				
			when "0001" =>		-- MOVI
				reg_wr_ena <= '1';
				if (op_sign_extend = '1') then
					reg_dst_in <= movi_high_byte & imm_value;
				else
					reg_dst_in <= reg_dst_out(15 downto 8) & imm_value;
				end if;
			
			when "0100" =>		-- alu op
				reg_wr_ena <= '1';
				reg_dst_in <= alu_result;
				zero_next <= alu_zero;
				negative_next <= alu_negative;
				
			-- LD/LDI/IN
			when "0010" =>
				reg_wr_ena <= '1';
				if (op_sign_extend = '1') then
					reg_dst_in <= ld_high_byte & data_mem_data_in;
				else
					reg_dst_in <= reg_dst_out(15 downto 8) & data_mem_data_in;
				end if;
				mem_io_select <= not op(3);	
				
			when "1010" =>
				reg_wr_ena <= '1';
				if (op_sign_extend = '1') then
					reg_dst_in <= ld_high_byte & data_mem_data_in;
				else
					reg_dst_in <= reg_dst_out(15 downto 8) & data_mem_data_in;
				end if;
				mem_io_select <= not op(3);	

			-- ST/STI/OUT
			when "0011" =>
				mem_io_select <= not op(3);
				mem_write <= '1';
				
			when "1011" =>
				mem_io_select <= not op(3);
				mem_write <= '1';
				
			-- Branches
			when "0101" =>				
				case branch_cond is
					when "00" =>	-- BREQ
						if (zero = '1') then
							pc_next <= jump_target;
						end if;
					
					when "01" =>	-- BRNE
						if (zero = '0') then
							pc_next <= jump_target;
						end if;
						
					when "10" =>	-- BRA
						pc_next <= jump_target;
						
					when others =>
						pc_next <= pc_reg + 1;
							
				end case;
				
			-- Branch to subroutine
			when "0111" =>
				mem_write <= '1';
				stack_write_access <= '1';
				sp_next <= sp_reg - 1;
				data_mem_data_out <= pc_reg + 1;
				case branch_cond is
					when "00" =>	-- BREQ
						if (zero = '1') then
							pc_next <= jump_target;
						end if;
					
					when "01" =>	-- BRNE
						if (zero = '0') then
							pc_next <= jump_target;
						end if;
						
					when "10" =>	-- BRA
						pc_next <= jump_target;
						
					when others =>
						pc_next <= pc_reg + 1;
						
				end case;
				
			when "1000"	=>		-- RET
				stack_read_access <= '1';
				sp_next <= sp_reg + 1;
				pc_next <= data_mem_data_in;

			when "1001" =>		-- PUSH & POP
				if (op_pop_push = '0') then
					stack_write_access <= '1';
					sp_next <= sp_reg - 1;
					mem_write <= '1';
					data_mem_data_out <= reg_dst_out(7 downto 0);		-- can push only lower byte
				else
					stack_read_access <= '1';
					sp_next <= sp_reg + 1;
					reg_wr_ena <= '1';
					reg_dst_in <= reg_dst_out(15 downto 8) & data_mem_data_in;  -- can pop only lower byte
				end if;
			
				
			when "0110" =>		-- CPYDATA
				-- write immediate value to (t) and inc t in one instruction w00t
				mem_write <= '1';
				alu_op <= "1100";
				reg_wr_ena <= '1';
				reg_dst_in <= alu_result;
				data_mem_data_out <= imm_value;
				reg_src1_select <= reg_dst_select;
			
			when "1111" =>
				pc_next <= pc_reg;
				halted_next <= '1';
			when others =>
			
		end case;
	end process;
	
	pgm_mem_addr <= pc_reg;
	data_mem_addr <= sp_reg when stack_write_access = '1' else
						  sp_next when stack_read_access = '1' else
						  reg_src1_out(7 downto 0) when op_indirect_addr = '1' else imm_address;
	data_mem_wr_ena <= clk_ena and mem_write;
	jump_target <= reg_src1_out(7 downto 0) when op_register_jump_target = '1' else imm_value;
	
	-- scan logic
	process (scan_reg, scan_enable, scan_input, scan_reset, pc_reg, sr_reg, instruction, reg_file_scan_output)
	begin
		if (scan_reset = '1') then
			scan_reg_next <= instruction & sr_reg & pc_reg & sp_reg;
		elsif (scan_enable = '1') then
			scan_reg_next <= reg_file_scan_output & scan_reg(scan_length - 1 downto 1); 
		else
			scan_reg_next <= scan_reg;
		end if;
	end process;
	
	reg_file_scan_input <= scan_input;
	scan_output <= scan_reg(0);
	
end Behavioral;