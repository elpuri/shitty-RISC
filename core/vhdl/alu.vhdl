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


entity alu is port (
	op : in std_logic_vector(3 downto 0);
	src1 : in std_logic_vector(15 downto 0);
	src2 : in std_logic_vector(15 downto 0);
	result : out std_logic_vector(15 downto 0);
	carry_out : out std_logic;
	carry_in : in std_logic;
	zero : out std_logic;
	overflow : out std_logic;
	negative : out std_logic

);
end alu;

architecture Behavioral of alu is

signal adder_src1, adder_src2, adder_result : std_logic_vector(15 downto 0);
signal adder_addsub, adder_carry_in, adder_carry_out : std_logic;
signal op_result : std_logic_vector(15 downto 0);

begin
	adder : entity work.adder port map (
		dataa => adder_src1,
		datab => adder_src2,
		cout => adder_carry_out,
		cin => adder_carry_in,
		result => adder_result,
		overflow => overflow,
		add_sub => adder_addsub
	);
	
	
	process (op, src1, src2, adder_result)		
	begin
		adder_addsub <= '-';
		adder_carry_in <= '-';
		adder_src1 <= src1;
		adder_src2 <= src2;

		case op is
			when "0000" =>		-- add
				adder_addsub <= '1';
				adder_carry_in <= carry_in;
				op_result <= adder_result;
			when "0001" =>		-- sub
				adder_addsub <= '0';
				adder_carry_in <= not carry_in;
				op_result <= adder_result;
			when "0010" =>		-- shift right
				op_result <= src1(15) & src1(15 downto 1);
			when "0011" =>		-- shift left
				op_result <= src1(14 downto 0) & "0";
			when "0100" =>		-- zero
				op_result <= (others => '0');
			when "0101" =>		-- swap
				op_result <= src1(7 downto 0) & src1(15 downto 8);
			when "0110" =>		-- not
				op_result <= not src1;
			when "0111" =>		-- or
				op_result <= src1 or src2;
			when "1000" =>		-- and
				op_result <= src1 and src2;
			when "1001" =>		-- xor
				op_result <= src1 xor src2;
			when "1010" =>		-- nop
				op_result <= src1;
			when "1011" =>		-- dec
				op_result <= adder_result;
				adder_addsub <= '0';
				adder_src2 <= x"0001";
				adder_carry_in <= '1';
			when "1100" =>		-- inc
				op_result <= adder_result;
				adder_addsub <= '1';
				adder_src2 <= x"0001";
				adder_carry_in <= '0';
			when others =>
				op_result <= (others => '0');
				
		end case;
	end process;
	
	zero <= '1' when op_result = "0000000000000000" else '0';
	negative <= '1' when op_result(15) = '1' else '0';
	carry_out <= adder_carry_out when op(3 downto 1) = "000" else '0';		-- use carry_out when op is add or sub
	result <= op_result;
	
end Behavioral;