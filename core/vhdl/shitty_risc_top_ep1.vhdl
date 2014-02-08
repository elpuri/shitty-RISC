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


entity shitty_risc_top_ep1 is Port (
	clk_50 : in std_logic;
	uart_rxd : in std_logic;
	uart_txd : out std_logic;
	leds : out std_logic_vector(5 downto 0);
	btn : in std_logic_vector(3 downto 0);
	seven_seg : out std_logic_vector(7 downto 0);
	seven_seg_an : out std_logic_vector(3 downto 0);
	buzz : out std_logic;
	hd44780_rw : out std_logic;
	hd44780_rs : out std_logic;
	hd44780_en : out std_logic;
	hd44780_data : inout std_logic_vector(7 downto 0)
);
end shitty_risc_top_ep1;


architecture Behavioral of shitty_risc_top_ep1 is

signal pgm_ram_data_in : std_logic_vector(15 downto 0);
signal pgm_ram_data_out : std_logic_vector(15 downto 0);
signal pgm_ram_addr : std_logic_vector(7 downto 0);
signal pgm_ram_wren : std_logic;

signal data_ram_addr : std_logic_vector(7 downto 0);
signal data_ram_data_in : std_logic_vector(7 downto 0);
signal data_ram_data_out : std_logic_vector(7 downto 0);
signal data_ram_wren : std_logic;

signal debugger_pgm_ram_data_out : std_logic_vector(15 downto 0);
signal debugger_pgm_ram_addr : std_logic_vector(7 downto 0);
signal debugger_pgm_ram_wren : std_logic;
signal debugger_data_ram_addr : std_logic_vector(7 downto 0);
signal debugger_data_ram_data_in : std_logic_vector(7 downto 0);
signal debugger_data_ram_data_out : std_logic_vector(7 downto 0);
signal debugger_data_ram_wren : std_logic;

signal cpu_pgm_ram_data_in : std_logic_vector(15 downto 0);
signal cpu_pgm_ram_addr : std_logic_vector(7 downto 0);
signal cpu_data_ram_data_in : std_logic_vector(7 downto 0);
signal cpu_data_ram_data_out : std_logic_vector(7 downto 0);
signal cpu_data_ram_addr : std_logic_vector(7 downto 0);
signal cpu_data_ram_wren : std_logic;
signal cpu_mem_io_select : std_logic;

signal debugger_mem_access : std_logic;
signal debugger_cpu_clk_ena : std_logic;
signal debugger_cpu_reset : std_logic;
signal debugger_scan_reset : std_logic;
signal debugger_scan_enable : std_logic;
signal debugger_leds, debugger_7seg : std_logic_vector(3 downto 0);

signal display_device_address : std_logic_vector(2 downto 0);
signal display_device_data : std_logic_vector(7 downto 0);
signal display_device_wr_ena : std_logic;
signal display_device_select : std_logic;

signal beeper_data : std_logic_vector(7 downto 0);
signal beeper_wr_ena, beeper_output, beeper_select : std_logic;

signal cpu_debug_output : std_logic;
signal io_write : std_logic;

signal reset : std_logic;

signal terminal_scan_input : std_logic;

signal lcdctrl_data_in, lcdctrl_data_out : std_logic_vector(7 downto 0);
signal lcdctrl_write_strobe, lcdctrl_rs, lcdctrl_ready_read : std_logic;
signal lcdctrl_select : std_logic;	-- chip select

begin
	debugger : entity work.debugger port map (
		clk_50 => clk_50,
		reset => reset,
		serial_rx => uart_rxd,
		serial_tx => uart_txd,
		mem_access => debugger_mem_access,
		pgm_mem_addr => debugger_pgm_ram_addr,
		pgm_mem_data_out => debugger_pgm_ram_data_out,
		pgm_mem_wren => debugger_pgm_ram_wren,
		data_mem_addr => debugger_data_ram_addr,
		data_mem_data_in => debugger_data_ram_data_in,
		data_mem_data_out => debugger_data_ram_data_out,
		data_mem_wren => debugger_data_ram_wren,
		cpu_reset => debugger_cpu_reset,
		cpu_clk_ena => debugger_cpu_clk_ena,
		debug_scan_reset => debugger_scan_reset,
		debug_scan_input => cpu_debug_output,
		debug_scan_enable => debugger_scan_enable
	);

	terminal_scan_input <= '0';
	
	cpu : entity work.shitty_risc port map (
		clk => clk_50,
		clk_ena => debugger_cpu_clk_ena,
		reset => reset,
		scan_input => terminal_scan_input,
		scan_output => cpu_debug_output,
		scan_reset => debugger_scan_reset,
		scan_enable => debugger_scan_enable,
		pgm_mem_addr => cpu_pgm_ram_addr,
		pgm_mem_data_in => cpu_pgm_ram_data_in,
		data_mem_addr => cpu_data_ram_addr,
		data_mem_data_out => cpu_data_ram_data_out,
		data_mem_data_in => cpu_data_ram_data_in,
		data_mem_wr_ena => cpu_data_ram_wren,
		mem_io_select => cpu_mem_io_select
	);
		
	pgm_ram_addr <= debugger_pgm_ram_addr when debugger_mem_access = '1' else cpu_pgm_ram_addr;
	pgm_ram_data_in <= debugger_pgm_ram_data_out;
	cpu_pgm_ram_data_in <= pgm_ram_data_out;
	pgm_ram_wren <= debugger_pgm_ram_wren when debugger_mem_access = '1' else '0';		-- CPU can't write program mem
	
	data_ram_addr <= debugger_data_ram_addr when debugger_mem_access = '1' else cpu_data_ram_addr;
	data_ram_wren <= debugger_data_ram_wren when debugger_mem_access = '1' else (cpu_data_ram_wren and cpu_mem_io_select);
	debugger_data_ram_data_in <= data_ram_data_out;
	data_ram_data_in <= debugger_data_ram_data_out when debugger_mem_access = '1' else cpu_data_ram_data_out;

	-- Allocating each 'device' 4 bits of address space, should be enough...
	-- Anding with cpu_clk_ena because the cpu outputs glitch 
	io_write <= '1' when (cpu_mem_io_select = '0' and cpu_data_ram_wren = '1' and debugger_cpu_clk_ena = '1') else '0';
	
	display_device_select <= '1' when cpu_data_ram_addr(7 downto 4) = "0000" else '0';
	beeper_select <= '1' when cpu_data_ram_addr(7 downto 4) = "0001" else '0';
	lcdctrl_select <= '1' when cpu_data_ram_addr(7 downto 4) = "0010" else '0';
	
	display_device_wr_ena <= display_device_select and io_write;	
	beeper_wr_ena <= beeper_select and io_write;
	lcdctrl_write_strobe <= lcdctrl_select and io_write;
	lcdctrl_rs <= cpu_data_ram_addr(0);		-- 0x20 register write, 0x21 lcd ram write
	lcdctrl_data_in <= cpu_data_ram_data_out;
	
	-- Muxing ram, device and device outputs to cpu data input
	process (cpu_mem_io_select, cpu_data_ram_addr, display_device_select, beeper_select,
				data_ram_data_out)
	begin
		cpu_data_ram_data_in <= data_ram_data_out;

		if (cpu_mem_io_select = '0') then
			cpu_data_ram_data_in <= (others => '0');	
		end if;

	end process;
	
	pgm_mem : entity work.ep1_pgmram port map (
		address => pgm_ram_addr,
		clock => clk_50,
		wren => pgm_ram_wren,
		data => pgm_ram_data_in,
		q => pgm_ram_data_out
	);

	data_mem : entity work.ep1_dataram port map (
		address => data_ram_addr,
		clock => clk_50,
		wren => data_ram_wren,
		q => data_ram_data_out,
		data => data_ram_data_in
	);

	beeper_device : entity work.beeper_device port map (
		clk => clk_50,
		reset => reset,
		wr_ena => beeper_wr_ena,
		data => beeper_data,
		output => beeper_output
	);
	
	buzz <= beeper_output;
	beeper_data <= cpu_data_ram_data_out;
	
	display_device : entity work.display_device port map (
		clk => clk_50,
		display => seven_seg,
		anodes => seven_seg_an,
		reset => reset,
		address => display_device_address,
		data => display_device_data,
		wr_ena => display_device_wr_ena
	);

	-- The EP1 board supplies 5V to the LCD, but the  
	hd44780_rw <= '0';
	hd44780_data <= lcdctrl_data_out;
	
	hd44780 : entity work.lcd_controller port map (
		clk_50 => clk_50,
		reset => reset,
		di => lcdctrl_data_in,
		strobe => lcdctrl_write_strobe,
		register_select => lcdctrl_rs,
		lcd_en => hd44780_en,
		lcd_rs => hd44780_rs,
		lcd_do => lcdctrl_data_out
	);
	
	display_device_address <= cpu_data_ram_addr(2 downto 0);
	display_device_data <= cpu_data_ram_data_out;
	reset <= not btn(3) or debugger_cpu_reset;
    
end Behavioral;

