----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: Testbench for the DDS Controller (with BRAM)
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

----------------------------------------------------------------------------
-- Entity definition
entity tb_dds_controller is
end tb_dds_controller;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture testbench of tb_dds_controller is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
constant SAMPLING_FREQ  : real := 48000.00;     -- 48 kHz sampling rate
constant T_SAMPLE : real := (1.0/SAMPLING_FREQ)*1000000000.0;
constant CLOCK_PERIOD : time := integer(T_SAMPLE) * 1ns;
constant DATA_WIDTH : integer := 24;        -- DDS data width
constant PHASE_DATA_WIDTH : integer := 12;  -- DDS phase increment data width
constant SIM_WAIT_TIME : time := 10ms;     -- default wait time

----------------------------------------------------------------------------
-- Signals to hook up to DUT
signal clk : std_logic := '0';
signal enable, reset : std_logic := '1';
signal data_out : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
signal phase_increment : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := (others => '0');

----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------
-- DDS controller, uses block memory IP for storing samples
component dds_controller is
    Generic ( DATA_WIDTH : integer := DATA_WIDTH;               -- DDS data width
            PHASE_DATA_WIDTH : integer := PHASE_DATA_WIDTH);    -- DDS phase increment data width
    Port ( 
      clk_i         : in std_logic;
      enable_i      : in std_logic;
      reset_i       : in std_logic;
      phase_inc_i   : in std_logic_vector(PHASE_DATA_WIDTH-1 downto 0);
      
      data_o        : out std_logic_vector(DATA_WIDTH-1 downto 0)); 
end component;
----------------------------------------------------------------------------
begin

----------------------------------------------------------------------------
-- Component instantiations
----------------------------------------------------------------------------    
-- DDS controller (uses BRAM)
dut : dds_controller 
    port map (
        clk_i => clk,
        enable_i => enable,
        reset_i => reset,
        phase_inc_i => phase_increment,
        data_o => data_out);
----------------------------------------------------------------------------   
-- Processes
----------------------------------------------------------------------------   
-- Generate clock        
clock_gen_process : process
begin
	clk <= '0';				        -- start low
	wait for CLOCK_PERIOD/2;		-- wait for half a clock period
	loop							-- toggle, and loop
	  clk <= not(clk);
	  wait for CLOCK_PERIOD/2;
	end loop;
end process clock_gen_process;


----------------------------------------------------------------------------
-- Stimulus process
----------------------------------------------------------------------------
stim_proc : process
begin

----------------------------------------------------------------------------
-- Reset/Initialize
----------------------------------------------------------------------------
enable <= '0';
reset <= '1';
phase_increment <= x"02D";
wait for CLOCK_PERIOD*10;
reset <= '0';
wait until rising_edge(clk);

----------------------------------------------------------------------------
-- Enable the DDS controller 
----------------------------------------------------------------------------
enable <= '1';
wait for SIM_WAIT_TIME;

----------------------------------------------------------------------------
-- Disable the DDS controller 
----------------------------------------------------------------------------
enable <= '0';
wait for CLOCK_PERIOD*20;

----------------------------------------------------------------------------
-- Enable the DDS controller, and change the phase increment
----------------------------------------------------------------------------
enable <= '1';
phase_increment <= x"032"; 
wait for SIM_WAIT_TIME;

----------------------------------------------------------------------------
-- Change the phase increment again
----------------------------------------------------------------------------
phase_increment <= x"038"; 
wait for SIM_WAIT_TIME;

----------------------------------------------------------------------------
-- Enable and reset (reset should take priority)
----------------------------------------------------------------------------
reset <= '1';
wait for CLOCK_PERIOD*20;
reset <= '0';

wait for SIM_WAIT_TIME;

std.env.stop;   -- Stop the simulation

end process stim_proc;

end testbench;