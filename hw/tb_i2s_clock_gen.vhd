----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
----------------------------------------------------------------------------
--  ENGS 128
--  Author: Kendall Farnham
----------------------------------------------------------------------------
--  Description: Testbench for I2S clock generation
--
--  Verifies the following frequencies:
--    MCLK  : 12.5  MHz  (period =  80.0 ns)
--    BCLK  : 3.125 MHz  (period = 320.0 ns)
--    LRCLK : 48.828 kHz (period =  20.48 us)
--
--  Run for at least 3 full LRCLK cycles (~62 us) to observe all clocks.
--  In the waveform, verify:
--    1. MCLK period  =  80 ns  (8 sysclk cycles)  -- actually 10 sysclk cycles → 80ns ✓
--    2. BCLK = MCLK / 4  → period = 320 ns
--    3. LRCLK = BCLK / 64 → period ≈ 20.48 us
--    4. All clocks have 50% duty cycle
--    5. Forwarded clocks (fwd_o) match their internal counterparts
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------
-- Entity definition (no ports — testbench is self-contained)
----------------------------------------------------------------------------
entity tb_i2s_clock_gen is
end tb_i2s_clock_gen;

----------------------------------------------------------------------------
architecture testbench of tb_i2s_clock_gen is

----------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------
constant SYSCLK_PERIOD : time := 8 ns;     -- 125 MHz

-- Expected derived periods (for waveform annotation reference)
-- MCLK  = 125 MHz / 10 = 12.5 MHz  → period = 80  ns
-- BCLK  = 12.5 MHz / 4 = 3.125 MHz → period = 320 ns
-- LRCLK = 3.125 MHz /64 = 48828 Hz → period ≈ 20480 ns

constant SIM_DURATION : time := 100 us;    -- enough for ~5 LRCLK cycles

----------------------------------------------------------------------------
-- DUT signals
----------------------------------------------------------------------------
signal clk              : std_logic := '0';

-- Forwarded (off-chip) clocks
signal mclk_fwd         : std_logic := '0';
signal bclk_fwd         : std_logic := '0';
signal adc_lrclk_fwd    : std_logic := '0';
signal dac_lrclk_fwd    : std_logic := '0';

-- Internal (on-chip) clocks
signal mclk             : std_logic := '0';
signal bclk             : std_logic := '0';
signal lrclk            : std_logic := '0';

----------------------------------------------------------------------------
-- Component declaration
----------------------------------------------------------------------------
component i2s_clock_gen is
    Port (
        sysclk_125MHz_i  : in  std_logic;
        mclk_fwd_o       : out std_logic;
        bclk_fwd_o       : out std_logic;
        adc_lrclk_fwd_o  : out std_logic;
        dac_lrclk_fwd_o  : out std_logic;
        mclk_o           : out std_logic;
        bclk_o           : out std_logic;
        lrclk_o          : out std_logic);
end component;

----------------------------------------------------------------------------
begin

----------------------------------------------------------------------------
-- Instantiate DUT
----------------------------------------------------------------------------
dut : i2s_clock_gen
    port map (
        sysclk_125MHz_i  => clk,
        mclk_fwd_o       => mclk_fwd,
        bclk_fwd_o       => bclk_fwd,
        adc_lrclk_fwd_o  => adc_lrclk_fwd,
        dac_lrclk_fwd_o  => dac_lrclk_fwd,
        mclk_o           => mclk,
        bclk_o           => bclk,
        lrclk_o          => lrclk);

----------------------------------------------------------------------------
-- 125 MHz system clock
----------------------------------------------------------------------------
sysclk_gen : process
begin
    clk <= '0';
    wait for SYSCLK_PERIOD / 2;
    loop
        clk <= not clk;
        wait for SYSCLK_PERIOD / 2;
    end loop;
end process sysclk_gen;

----------------------------------------------------------------------------
-- Run then stop
----------------------------------------------------------------------------
sim_control : process
begin
    wait for SIM_DURATION;
    std.env.stop;
end process sim_control;

end testbench;
