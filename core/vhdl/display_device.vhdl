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

entity display_device is port (
	clk : in std_logic;
	reset : in std_logic;
	address : in std_logic_vector(2 downto 0);
	data : in std_logic_vector(7 downto 0);
	wr_ena : in std_logic;
	anodes : out std_logic_vector(3 downto 0);
	display : out std_logic_vector(7 downto 0)
);
end display_device;

architecture Behavioral of display_device is

subtype reg is std_logic_vector(7 downto 0);
type regarray is array (0 to 4) of reg;
signal registers, registers_next : regarray;
signal active_element: std_logic_vector(1 downto 0);

signal encoding_enabled : std_logic;
signal display_enabled : std_logic;

signal current_value : std_logic_vector(7 downto 0);
signal encoded_segments : std_logic_vector(6 downto 0);

signal clk_divider : std_logic_vector(15 downto 0);
signal tick : std_logic;
begin

	process (clk, reset) 
	begin
		if (reset = '1') then
			registers(0) <= (others => '0');
			registers(1) <= (others => '0');
			registers(2) <= (others => '0');
			registers(3) <= (others => '0');
			registers(4) <= (others => '0');
			active_element <= (others => '0');
		elsif (clk'event and clk = '1') then
			registers <= registers_next;
			clk_divider <= clk_divider + 1;
			if (tick = '1') then
				active_element <= active_element + 1;
			end if;
		end if;
	end process;
	
	-- register access logic
	process (wr_ena, address, data, registers)
	begin
		registers_next <= registers;
		if (wr_ena = '1') then
			case address is 
				when "000" =>
					registers_next(0) <= data;
				when "001" =>
					registers_next(1) <= data;
				when "010" =>
					registers_next(2) <= data;
				when "011" =>
					registers_next(3) <= data;
				when "100" =>
					registers_next(4) <= data;
				when others =>
			end case;
		end if;
	end process;
	
	process (registers, active_element, display_enabled)
	begin
		case active_element is 
			when "00" =>
				current_value <= registers(3);
				anodes <= "0111";
			when "01" =>
				current_value <= registers(2);
				anodes <= "1011";
			when "10" =>
				current_value <= registers(1);
				anodes <= "1101";
			when "11" =>
				current_value <= registers(0);
				anodes <= "1110";
		end case;
		if (display_enabled = '0') then
			anodes <= "1111";
		end if;
	end process;
	
	tick <= '1' when clk_divider = 0 else '0';
	display_enabled <= registers(4)(0);
	encoding_enabled <= registers(4)(1);

	bin_to_7seg : entity work.bin_to_7seg port map (
		value => current_value(3 downto 0),
		display => encoded_segments
	);
	
	display <= (encoded_segments & not current_value(7)) when encoding_enabled = '1' else current_value;

end Behavioral;