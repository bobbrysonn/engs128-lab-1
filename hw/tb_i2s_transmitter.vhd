----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: Testbench for the I2S transmitter
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

----------------------------------------------------------------------------
-- Entity definition
entity tb_i2s_transmitter is
end tb_i2s_transmitter;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture testbench of tb_i2s_transmitter is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
-- Timing constants
constant CLOCK_PERIOD : time := 8ns;            -- 125 MHz system clock period
constant AC_DATA_WIDTH : integer := 24;

signal clk : std_logic := '0';
----------------------------------------------------------------------------
-- Audio codec I2S signals
signal mclk 			    : std_logic := '0';
signal bclk 			    : std_logic := '0';
signal lrclk   			    : std_logic := '0';
signal left_audio_data_tx	: std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal right_audio_data_tx  : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal i2s_serial_data      : std_logic := '0';

----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------
-- I2S transmitter
component i2s_transmitter is
    Generic (AC_DATA_WIDTH : integer := AC_DATA_WIDTH);
    Port (

        -- Timing
		mclk_i    : in std_logic;	
		bclk_i    : in std_logic;	
		lrclk_i   : in std_logic;
		
		-- Data
		left_audio_data_i     : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_i    : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		dac_serial_data_o     : out std_logic);  
end component; 

----------------------------------------------------------------------------------
-- Clock generation
component i2s_clock_gen is
    Port (

        -- System clock in
		sysclk_125MHz_i   : in  std_logic;	
		
		-- Forwarded clocks
		mclk_fwd_o		  : out std_logic;	
		bclk_fwd_o        : out std_logic;
		adc_lrclk_fwd_o   : out std_logic;
		dac_lrclk_fwd_o   : out std_logic;

        -- Clocks for I2S components
		mclk_o		      : out std_logic;	
		bclk_o            : out std_logic;
		lrclk_o           : out std_logic);  
end component;

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Component instantiations
---------------------------------------------------------------------------- 
-- Clock generation
clock_generation: i2s_clock_gen
port map(
    sysclk_125MHz_i => clk,
    mclk_fwd_o      => open,
    bclk_fwd_o      => open,
    adc_lrclk_fwd_o => open,
    dac_lrclk_fwd_o => open,
    mclk_o          => mclk,
    bclk_o			=> bclk,
	lrclk_o			=> lrclk);
	
---------------------------------------------------------------------------- 
-- I2S transmitter
dut_audio_transmitter: i2s_transmitter
port map(
    mclk_i              => mclk,
    bclk_i              => bclk,
    lrclk_i             => lrclk,
    left_audio_data_i   => left_audio_data_tx,		-- Drive these inputs
    right_audio_data_i  => right_audio_data_tx,
    dac_serial_data_o   => i2s_serial_data);		-- DUT output

----------------------------------------------------------------------------   
-- Processes
----------------------------------------------------------------------------   
-- Generate clock        
clock_gen_process : process
begin
	clk <= '0';				-- start low
	wait for CLOCK_PERIOD/2;		-- wait for half a clock period
	loop							-- toggle, and loop
	  clk <= not(clk);
	  wait for CLOCK_PERIOD/2;
	end loop;
end process clock_gen_process;

----------------------------------------------------------------------------
-- Set data to a constant value (this is the driving input)
----------------------------------------------------------------------------
left_audio_data_tx <= x"8F3";
right_audio_data_tx <= x"90F";
   



end testbench;