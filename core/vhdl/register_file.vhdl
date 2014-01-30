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
use IEEE.NUMERIC_STD.ALL;

entity register_file is port (
	clk : in std_logic;
	reset : in std_logic;
	clk_ena : in std_logic;
	
	scan_reset : in std_logic;
	scan_input : in std_logic;
	scan_output : out std_logic;
	scan_enable : in std_logic;
	
	src1_select : in std_logic_vector(1 downto 0);
	src2_select : in std_logic_vector(1 downto 0);
	dst_select : in std_logic_vector(1 downto 0);
	dst_wr_ena : in std_logic;
	
	src1_out : out std_logic_vector(15 downto 0);
	src2_out : out std_logic_vector(15 downto 0);
	dst_in : in std_logic_vector(15 downto 0);
	dst_out : out std_logic_vector(15 downto 0)
);

end register_file;

architecture Behavioral of register_file is

type regarray is array (0 to 3) of std_logic_vector(15 downto 0);
signal registers, registers_next : regarray;

signal scan_reg, scan_reg_next : std_logic_vector(16 * 4 - 1 downto 0);

begin
	process (reset, clk, clk_ena, registers_next, scan_reg_next)
	begin
		if (reset = '1') then
			registers <= (others => (others => '0'));
			registers(0) <= (others => '0');
			registers(1) <= (others => '0');
			registers(2) <= (others => '0');
			registers(3) <= (others => '0');
		elsif (clk'event and clk = '1') then
			if (clk_ena = '1') then
				registers <= registers_next;
			end if;
			scan_reg <= scan_reg_next;
		end if;
		

	end process;
	
	process (registers, registers_next, dst_select, dst_in, dst_wr_ena)
	begin
		registers_next <= registers;
		if (dst_wr_ena = '1') then
			registers_next(to_integer(unsigned(dst_select))) <= dst_in;
		end if;	
	end process;
	
	src1_out <= registers(to_integer(unsigned(src1_select)));
	src2_out <= registers(to_integer(unsigned(src2_select)));
	dst_out <= registers(to_integer(unsigned(dst_select)));

	-- scan logic
	process (scan_reg, scan_enable, scan_input, scan_reset, registers)
	begin
		if (scan_reset = '1') then
			scan_reg_next <= registers(3) & registers(2) & registers(1) & registers(0);
		elsif (scan_enable = '1') then
			scan_reg_next <= scan_input & scan_reg(16 * 4 - 1 downto 1); 
		else
			scan_reg_next <= scan_reg;
		end if;
	
	end process;
	
	scan_output <= scan_reg(0);
	
end Behavioral;