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


entity debug_mem_op_controller is port (
	clk : in std_logic;
	reset : in std_logic;
	
	busy : out std_logic;
	rw : in std_logic;
	pgm_data_mem_select : in std_logic;
	
	mem_addr : in std_logic_vector(7 downto 0);			-- read/write starting from address
	run_length : in std_logic_vector(7 downto 0);		-- how many bytes/instructions to read/write
	
	pgm_mem_addr : out std_logic_vector(7 downto 0);
	pgm_mem_data_out : out std_logic_vector(15 downto 0);
	pgm_mem_wren : out std_logic;
   data_mem_addr : out std_logic_vector(7 downto 0);
	data_mem_data_out : out std_logic_vector(7 downto 0);
	data_mem_data_in : in std_logic_vector(7 downto 0);
	data_mem_wren : out std_logic;
	
	strobe : in std_logic;
	
	rx_data : in std_logic_vector(7 downto 0);
	rx_ready : in std_logic;
	
	tx_data : out std_logic_vector(7 downto 0);
	tx_strobe : out std_logic;
	tx_idle : in std_logic;
	
	debug_data : out std_logic_vector(3 downto 0)
);
end debug_mem_op_controller;
architecture Behavioral of debug_mem_op_controller is

type controller_state is (idle, 
								  rx_pgm_byte1, rx_pgm_byte2, write_pgm_byte, 
								  rx_data_byte, write_data_byte, 
								  tx_data_byte, read_data_byte, read_data_byte_latency);

signal bytes_left_reg, bytes_left_next : std_logic_vector(7 downto 0);
signal mem_addr_reg, mem_addr_next : std_logic_vector(7 downto 0);
signal state_reg, state_next : controller_state;
signal rx_byte_reg, rx_byte_next : std_logic_vector(7 downto 0);
signal pgm_mem_byte_reg, pgm_mem_byte_next : std_logic_vector(15 downto 0);
signal debug_data_reg, debug_data_next : std_logic_vector(3 downto 0);

begin

	process (reset, clk)
	begin
		if (reset = '1') then
			bytes_left_reg <= (others => '0');
			mem_addr_reg <= (others => '0');
			state_reg <= idle;
			rx_byte_reg <= (others => '0');
			debug_data_reg <= "0000";
		elsif (clk'event and clk = '1') then
			state_reg <= state_next;
			bytes_left_reg <= bytes_left_next;
			mem_addr_reg <= mem_addr_next;
			rx_byte_reg <= rx_byte_next;
			debug_data_reg <= debug_data_next;
			pgm_mem_byte_reg <= pgm_mem_byte_next;
		end if;
	end process;
	
	process (state_reg, rw, mem_addr, pgm_data_mem_select, strobe, rx_ready, rx_data, run_length, data_mem_data_in,
				rx_byte_reg, mem_addr_reg, bytes_left_reg, tx_idle, bytes_left_next, debug_data_reg, pgm_mem_byte_reg)
	begin
		state_next <= state_reg;
		bytes_left_next <= bytes_left_reg;
		mem_addr_next <= mem_addr_reg;
		data_mem_wren <= '0';
		pgm_mem_wren <= '0';
		tx_strobe <= '0';
		rx_byte_next <= rx_byte_reg;
		debug_data_next <= debug_data_reg;
		pgm_mem_byte_next <= pgm_mem_byte_reg;
		case state_reg is 
			when idle =>
--				debug_data_next <= "0000";
				if (strobe = '1') then
					bytes_left_next <= run_length;		-- run length of 0 is 256
					mem_addr_next <= mem_addr;
					
					if (pgm_data_mem_select = '1') then
						state_next <= rx_pgm_byte1;
					else
						if (rw = '1') then
							state_next <= read_data_byte;
						else
							state_next <= rx_data_byte;
						end if;
					end if;
				end if;
				
			when rx_pgm_byte1 =>
				if (rx_ready = '1') then
					pgm_mem_byte_next <= rx_data & "XXXXXXXX";
					state_next <= rx_pgm_byte2;
				end if;
				
			when rx_pgm_byte2 =>
				if (rx_ready = '1') then
					pgm_mem_byte_next <= pgm_mem_byte_reg(15 downto 8) & rx_data;
					state_next <= write_pgm_byte;
				end if;
		
			when write_pgm_byte =>
				debug_data_next <= "1111";
				pgm_mem_wren <= '1';
				bytes_left_next <= bytes_left_reg - 1;		-- words really, but hey...
				mem_addr_next <= mem_addr_reg + 1;

				if (bytes_left_next = 0) then
					debug_data_next <= "1110";
					state_next <= idle;
				else
					state_next <= rx_pgm_byte1;
				end if;
				
			-- Read data byte from serial for writing to data mem
			when rx_data_byte =>
				debug_data_next <= "0001";
				if (rx_ready = '1') then
					rx_byte_next <= rx_data;
					state_next <= write_data_byte;
				end if;
			
			-- Write byte to data mem and bail out if done
			when write_data_byte =>
				debug_data_next <= "0010";
				data_mem_wren <= '1';	-- rx_byte_reg is already wired to data_mem_data_out
				bytes_left_next <= bytes_left_reg - 1;
				if (bytes_left_next = 0) then
					state_next <= idle;
					debug_data_next <= "0101";
				else
					state_next <= rx_data_byte;
				end if;
				mem_addr_next <= mem_addr_reg + 1;
				
			when read_data_byte =>
				debug_data_next <= "1011";
				state_next <= read_data_byte_latency;
			
			when read_data_byte_latency =>
				tx_strobe <= '1';
				state_next <= tx_data_byte;
				
			when tx_data_byte =>
				if (tx_idle = '1') then
					bytes_left_next <= bytes_left_reg - 1;
					if (bytes_left_reg = "0000001") then
						debug_data_next <= "1100";	
						state_next <= idle;
					else
						mem_addr_next <= mem_addr_reg + 1;
						state_next <= read_data_byte;
						debug_data_next <= "1110";

					end if;
				end if;
				
		end case;
	end process;
	
	busy <= '0' when state_reg = idle else '1';
	
	data_mem_addr <= mem_addr_reg;
	data_mem_data_out <= rx_byte_reg;
	pgm_mem_addr <= mem_addr_reg;
	pgm_mem_data_out <= pgm_mem_byte_reg;
	tx_data <= data_mem_data_in;
	
	debug_data <= debug_data_reg;
end Behavioral;
