-- Copyright (c) 2014, Juha Turunen (turunen@iki.fi)
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

entity lcd_controller is
Port ( 
    clk_50 : in std_logic;
    reset : in std_logic;
    di : in std_logic_vector(7 downto 0);
    strobe : in std_logic;
    register_select : in std_logic;
    lcd_en : out std_logic;
    lcd_rs : out std_logic;
    lcd_do : out std_logic_vector(7 downto 0)
);
end lcd_controller;

architecture Behavioral of lcd_controller is

signal data_in_reg, data_in_reg_next : std_logic_vector(7 downto 0);
signal state_reg, state_reg_next : std_logic_vector(4 downto 0);
signal lcd_en_reg, lcd_en_reg_next : std_logic;
signal lcd_rs_reg, lcd_rs_reg_next : std_logic;

begin
    process(clk_50, reset)
    begin
        if reset = '1' then
            data_in_reg <= (others => '0');
            state_reg <= (others => '0');
            lcd_en_reg <= '0';
            lcd_rs_reg <= '0';
        else
            if clk_50'event and clk_50 = '1' then
                data_in_reg <= data_in_reg_next;
                state_reg <= state_reg_next;
                lcd_en_reg <= lcd_en_reg_next;
                lcd_rs_reg <= lcd_rs_reg_next;
            end if;
        end if;
    end process;
	 
	 lcd_do <= data_in_reg;
	 lcd_rs <= lcd_rs_reg;
	 lcd_en <= lcd_en_reg;

    process(state_reg, data_in_reg, lcd_en_reg, lcd_rs_reg, register_select, strobe, di)
    begin
        state_reg_next <= state_reg;
        data_in_reg_next <= data_in_reg;
        lcd_en_reg_next <= lcd_en_reg;
        lcd_rs_reg_next <= lcd_rs_reg;
		  
        case state_reg is
            when "00000" =>
					 lcd_en_reg_next <= '0';
                if strobe = '1' then
                    lcd_rs_reg_next <= register_select;
                    data_in_reg_next <= di;
                    state_reg_next <= "00001";
                end if;
                
				-- The intermediate states exist because RW and RS need to settle for at least 60ns before EN goes up
              
		  	   when "00100" =>
					 lcd_en_reg_next <= '1';	
  					 state_reg_next <= state_reg + 1;
					 
				when "11100" =>
					 lcd_en_reg_next <= '0';
					 state_reg_next <= "00000";

				when others =>		-- Go to state +1 by default
                state_reg_next <= state_reg + 1;
        end case;
    end process;
end Behavioral;