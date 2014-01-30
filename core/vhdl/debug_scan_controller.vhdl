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


entity debug_scan_controller is port (
	clk : in std_logic;
	reset : in std_logic;
	
	done : out std_logic;
	strobe : in std_logic;
	
	scan_reset : out std_logic;
	scan_input : in std_logic;
	scan_enable : out std_logic;
	
	tx_data : out std_logic_vector(7 downto 0);
	tx_strobe : out std_logic;
	tx_idle : in std_logic
);
end debug_scan_controller;

architecture Behavioral of debug_scan_controller is

type state is (idle, apply_reset, prepare_collect_byte, collect_byte, send_byte, wait_tx);

signal state_reg, state_next : state;

signal expected_scan_byte_count_reg, expected_scan_byte_count_next : std_logic_vector(5 downto 0);
signal collect_debug_byte_counter_reg, collect_debug_byte_counter_next : std_logic_vector(2 downto 0);
signal debug_byte_reg, debug_byte_next : std_logic_vector(7 downto 0);

begin
	process(reset, clk)
	begin
		if (reset = '1') then
			state_reg <= idle;
			expected_scan_byte_count_reg <= (others => '0');
			collect_debug_byte_counter_reg <= (others => '0');
		elsif (clk'event and clk = '1') then
			state_reg <= state_next;
			expected_scan_byte_count_reg <= expected_scan_byte_count_next;
			collect_debug_byte_counter_reg <= collect_debug_byte_counter_next;
			debug_byte_reg <= debug_byte_next;
		end if;
	end process;
	
	tx_data <= debug_byte_reg;
	
	process(state_reg, strobe, collect_debug_byte_counter_reg, debug_byte_reg, expected_scan_byte_count_reg,
			  scan_input, tx_idle, expected_scan_byte_count_next, collect_debug_byte_counter_next)
	begin
		done <= '0';
		tx_strobe <= '0';
		scan_enable <= '0';
		scan_reset <= '0';
		
		state_next <= state_reg;
		debug_byte_next <= debug_byte_reg;
		expected_scan_byte_count_next <= expected_scan_byte_count_reg;
		collect_debug_byte_counter_next <= collect_debug_byte_counter_reg;
		
		case state_reg is			
			when idle =>
				done <= '1';
				if (strobe = '1') then
					state_next <= apply_reset;
				end if;
				
			-- PC(1) + SR(1) + IR(2) + 4 * regs(2)	
			when apply_reset =>
				scan_reset <= '1';
				state_next <= prepare_collect_byte;
				expected_scan_byte_count_next <= conv_std_logic_vector(1 + 1 + 2 + 8, 6);
				
			when prepare_collect_byte =>
				collect_debug_byte_counter_next <= (others => '0');
				state_next <= collect_byte;
				
			when collect_byte =>
				scan_enable <= '1';
				collect_debug_byte_counter_next <= collect_debug_byte_counter_reg + 1;
				debug_byte_next <= scan_input & debug_byte_reg(7 downto 1);
				if (collect_debug_byte_counter_next = "000") then
					state_next <= send_byte;
				end if;
			
			when send_byte =>
				tx_strobe <= '1';
				state_next <= wait_tx;
				
			when wait_tx =>
				if (tx_idle ='1') then
					expected_scan_byte_count_next <= expected_scan_byte_count_reg - 1;
					if (expected_scan_byte_count_next = 0) then
						state_next <= idle;
					else
						state_next <= prepare_collect_byte;
					end if;
				end if;
		end case;
	end process;
	
end Behavioral;