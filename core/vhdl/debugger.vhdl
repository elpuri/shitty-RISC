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


entity debugger is port (
	clk_50 : in std_logic;
	reset : in std_logic;
	serial_rx : in std_logic;
	serial_tx : out std_logic;
	mem_access : out std_logic;
	pgm_mem_addr : out std_logic_vector(7 downto 0);
	pgm_mem_data_out : out std_logic_vector(15 downto 0);
	pgm_mem_wren : out std_logic;
	data_mem_addr : out std_logic_vector(7 downto 0);
	data_mem_data_out : out std_logic_vector(7 downto 0);
	data_mem_data_in : in std_logic_vector(7 downto 0);
	data_mem_wren : out std_logic;
	command_buffer : out std_logic_vector(31 downto 0);
	cpu_reset : out std_logic;
	cpu_clk_ena : out std_logic;
		
	debug_scan_reset : out std_logic;
	debug_scan_input : in std_logic;
	debug_scan_enable : out std_logic
);
end debugger;

architecture Behavioral of debugger is

type debugger_state is (idle, running, stepping, start_debug_scan, wait_debug_scan, start_mem_op,
								wait_mem_op, toggle_reset);

signal rx_data : std_logic_vector(7 downto 0);
signal rx_tick : std_logic;

signal cmd_ready_reg, cmd_ready_next : std_logic;
signal cmd_buffer_reg, cmd_buffer_next : std_logic_vector(31 downto 0);

signal cpu_clk_ena_reg, cpu_clk_ena_next : std_logic;

signal expected_rx_bytes_reg, expected_rx_bytes_next : std_logic_vector(1 downto 0);

-- cpu clock divider
signal cpu_clock_divider_reg : std_logic_vector(2 downto 0);

signal debugger_state_reg, debugger_state_next : debugger_state;

signal tx_idle, tx_data_strobe, scan_controller_tx_strobe : std_logic;
signal tx_data, scan_controller_tx_data : std_logic_vector(7 downto 0);

signal scan_controller_done, scan_controller_strobe : std_logic;
signal scan_controller_scan_reset, scan_controller_scan_enable : std_logic;

-- mem op controller
signal memctl_busy, memctl_rw, memctl_pgm_data_mem_select, memctl_data_mem_wren, memctl_pgm_mem_wren : std_logic;
signal memctl_start_addr, memctl_run_length, memctl_pgm_mem_addr, 
		 memctl_data_mem_addr, memctl_data_mem_data_out, memctl_data_mem_data_in, 
		 memctl_tx_data : std_logic_vector(7 downto 0);
signal memctl_pgm_mem_data_out : std_logic_vector(15 downto 0);
signal memctl_strobe, memctl_tx_strobe : std_logic;
signal memctl_debug_data : std_logic_vector(3 downto 0);

begin

	process(clk_50, reset)
	begin
		if (reset = '1') then
			debugger_state_reg <= idle;
			cpu_clock_divider_reg <= (others => '0');
			expected_rx_bytes_reg <= "11";
			cmd_buffer_reg <= (others => '0');
			cmd_ready_reg <= '0';
			cpu_clk_ena_reg <= '0';
		else
			if (clk_50'event and clk_50 = '1') then
				debugger_state_reg <= debugger_state_next;
				cpu_clock_divider_reg <= cpu_clock_divider_reg + 1;
				expected_rx_bytes_reg <= expected_rx_bytes_next;
				cmd_ready_reg <= cmd_ready_next;
				cmd_buffer_reg <= cmd_buffer_next;
				cpu_clk_ena_reg <= cpu_clk_ena_next;
			end if;
		end if;
	end process;	
	
	-- FSM logic
	process(cmd_ready_reg, cmd_buffer_reg, debugger_state_reg, scan_controller_done, cpu_clock_divider_reg, 
			  memctl_busy)
	begin
		debugger_state_next <= debugger_state_reg;
		scan_controller_strobe <= '0';
		memctl_strobe <= '0';
		cpu_reset <= '0';
		case debugger_state_reg is
			when idle =>
				if (cmd_ready_reg = '1') then
					if (cmd_buffer_reg(31 downto 24) = "00000001") then
						debugger_state_next <= running;
					elsif (cmd_buffer_reg(31 downto 24) = "00000010") then
						debugger_state_next <= start_debug_scan;
					elsif (cmd_buffer_reg(31 downto 24) = "00000011") then
						debugger_state_next <= stepping;
					elsif (cmd_buffer_reg(31 downto 24) = "00000100") then
						debugger_state_next <= start_mem_op;
					elsif (cmd_buffer_reg(31 downto 24) = "00000101") then
						debugger_state_next <= toggle_reset;
					end if;			
				end if;
			
			when running =>
				if (cmd_ready_reg = '1' and cmd_buffer_reg(31 downto 24) = "00000000") then
					debugger_state_next <= idle;
				end if;
				
			when stepping =>
				if (cpu_clock_divider_reg = "00") then
					debugger_state_next <= idle;
				end if;
			
			when start_debug_scan =>
				debugger_state_next <= wait_debug_scan;
				scan_controller_strobe <= '1';
				
			when wait_debug_scan =>
				if (scan_controller_done = '1') then
					debugger_state_next <= idle;
				end if;
				
			when start_mem_op =>
				debugger_state_next <= wait_mem_op;
				memctl_strobe <= '1';
				
			when wait_mem_op =>
				if (memctl_busy = '0') then
					debugger_state_next <= idle;
				end if;
				
			when toggle_reset =>
				cpu_reset <= '1';
				debugger_state_next <= idle;
				
		end case;
	end process;
	

	
	-- cmd buffer receive logic
	process(rx_tick, expected_rx_bytes_reg, rx_data, cmd_buffer_reg, debugger_state_reg)
	begin
		expected_rx_bytes_next <= expected_rx_bytes_reg;
		cmd_ready_next <= '0';	-- enabled just for one cycle after receiving 4 bytes
		cmd_buffer_next <= cmd_buffer_reg;
		if (rx_tick = '1' and (debugger_state_reg = idle or debugger_state_reg = running)) then
			expected_rx_bytes_next <= expected_rx_bytes_reg - 1;
			cmd_buffer_next <= cmd_buffer_reg(23 downto 0) & rx_data;
			if (expected_rx_bytes_reg = "00") then
				cmd_ready_next <= '1';
			end if;
		end if;
	end process;
	
	
	mem_access <= '1' when debugger_state_reg = start_mem_op or debugger_state_reg= wait_mem_op else '0';
	
	
	scan_controller : entity work.debug_scan_controller port map (
		clk => clk_50,
		reset => reset,
		strobe => scan_controller_strobe,
		done => scan_controller_done,
		
		scan_reset => debug_scan_reset,
		scan_enable => debug_scan_enable,
		scan_input => debug_scan_input,
		
		tx_data => scan_controller_tx_data,
		tx_strobe => scan_controller_tx_strobe,
		tx_idle => tx_idle
	);
	
	mem_op_controller : entity work.debug_mem_op_controller port map (
		clk => clk_50,
		reset => reset,
		busy => memctl_busy,
		rw => memctl_rw,
		pgm_data_mem_select => memctl_pgm_data_mem_select,
		mem_addr => memctl_start_addr,
		run_length => memctl_run_length,
		pgm_mem_addr => memctl_pgm_mem_addr,
		pgm_mem_data_out => memctl_pgm_mem_data_out,
		pgm_mem_wren => memctl_pgm_mem_wren,
		data_mem_addr => memctl_data_mem_addr,
		data_mem_data_out => memctl_data_mem_data_out,
		data_mem_data_in => memctl_data_mem_data_in,
		data_mem_wren => memctl_data_mem_wren,
		strobe => memctl_strobe,
		rx_data => rx_data,
		rx_ready => rx_tick,
		tx_data => memctl_tx_data,
		tx_strobe => memctl_tx_strobe,
		tx_idle => tx_idle,
		debug_data => memctl_debug_data
	);
	
	memctl_start_addr <= cmd_buffer_reg(15 downto 8);
	memctl_run_length <= cmd_buffer_reg(7 downto 0);
	memctl_pgm_data_mem_select <= cmd_buffer_reg(16);
	memctl_rw <= cmd_buffer_reg(17);
	memctl_data_mem_data_in <= data_mem_data_in;
	data_mem_data_out <= memctl_data_mem_data_out;
	data_mem_addr <= memctl_data_mem_addr;
	data_mem_wren <= memctl_data_mem_wren;
	pgm_mem_addr <= memctl_pgm_mem_addr;
	pgm_mem_data_out <= memctl_pgm_mem_data_out;
	pgm_mem_wren <= memctl_pgm_mem_wren;
	
	-- mux debug_scan_controller tx stuff 
	tx_data_strobe <= memctl_tx_strobe when debugger_state_reg = wait_mem_op else scan_controller_tx_strobe;
	tx_data <= memctl_tx_data when debugger_state_reg = wait_mem_op else scan_controller_tx_data;
	
	
	tx : entity work.serial_tx port map (
		clk_50 => clk_50,
		reset => reset,
		tx => serial_tx,
		din => tx_data,
		din_strobe => tx_data_strobe,
		tx_idle => tx_idle
	);
	
	rx : entity work.serial_rx port map (
		clk_50 => clk_50,
		reset => reset,
		rx => serial_rx,
		dout => rx_data,
		dout_tick => rx_tick		
	);
	
	cpu_clk_ena <= '1' when cpu_clock_divider_reg = "000" and (debugger_state_reg = running or debugger_state_reg = stepping) else '0';
	command_buffer <= cmd_buffer_reg;
	
	
end Behavioral;