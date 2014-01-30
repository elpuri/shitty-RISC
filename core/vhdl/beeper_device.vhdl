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

entity beeper_device is port (
	clk : in std_logic;
	reset : in std_logic;
	data : in std_logic_vector(7 downto 0);
	wr_ena : in std_logic;
	output : out std_logic
);
end beeper_device;

architecture Behavioral of beeper_device is


signal control_reg, control_next : std_logic_vector(7 downto 0);
signal counter_reg, counter_next : std_logic_vector(17 downto 0);
signal waveform_reg, waveform_next : std_logic;
signal lut_output : std_logic_vector(11 downto 0);

begin

	process (clk, reset) 
	begin
		if (reset = '1') then
			control_reg <= x"FF";
			counter_reg <= (others => '0');
			waveform_reg <= '0';
		elsif (clk'event and clk = '1') then
			control_reg <= control_next;
			counter_reg <= counter_next;
			waveform_reg <= waveform_next;
		end if;
	end process;
	
	-- register access logic
	process (wr_ena, data, control_reg)
	begin
		control_next <= control_reg;
		if (wr_ena = '1') then
			control_next <= data;
		end if;
	end process;
	
	process (counter_reg, lut_output, waveform_reg)
	begin
		counter_next <= counter_reg + 1;
		waveform_next <= waveform_reg;
		if (counter_reg(17 downto 8) = lut_output(9 downto 0)) then
			counter_next <= (others => '0');
			waveform_next <= not waveform_reg;
		end if;
	end process;
	
	-- freq lookup table
	process (control_reg)
	begin
		-- LUT calculated with
		-- math.trunc(math.pow(2, -key / 12.0) * 1023)
		-- key ranges from 31 to 0
	
		case control_reg(4 downto 0) is 
			when "00000" => lut_output <= x"3FF";
			when "00001" => lut_output <= x"3C5";
			when "00010" => lut_output <= x"38F";
			when "00011" => lut_output <= x"35C";
			when "00100" => lut_output <= x"32B";
			when "00101" => lut_output <= x"2FE";
			when "00110" => lut_output <= x"2D3";
			when "00111" => lut_output <= x"2AA";
			when "01000" => lut_output <= x"284";
			when "01001" => lut_output <= x"260";
			when "01010" => lut_output <= x"23E";
			when "01011" => lut_output <= x"21D";
			when "01100" => lut_output <= x"1FF";
			when "01101" => lut_output <= x"1E2";
			when "01110" => lut_output <= x"1C7";
			when "01111" => lut_output <= x"1AE";
			when "10000" => lut_output <= x"195";
			when "10001" => lut_output <= x"17F";
			when "10010" => lut_output <= x"169";
			when "10011" => lut_output <= x"155";
			when "10100" => lut_output <= x"142";
			when "10101" => lut_output <= x"130";
			when "10110" => lut_output <= x"11F";
			when "10111" => lut_output <= x"10E";
			when "11000" => lut_output <= x"0FF";
			when "11001" => lut_output <= x"0F1";
			when "11010" => lut_output <= x"0E3";
			when "11011" => lut_output <= x"0D7";
			when "11100" => lut_output <= x"0CA";
			when "11101" => lut_output <= x"0BF";
			when "11110" => lut_output <= x"0B4";
			when "11111" => lut_output <= x"0AA";
		end case;
	end process;
	
	output <= '0' when control_reg = x"FF" else waveform_reg;
end Behavioral;