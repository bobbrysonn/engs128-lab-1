----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
----------------------------------------------------------------------------
--  ENGS 128
--  Author: Kendall Farnham
----------------------------------------------------------------------------
--  Description: I2S clock generation for SSM2603 audio codec
--
--  Generates three clocks from a 125 MHz system clock:
--    MCLK  = 125 MHz / 10  = 12.5  MHz  (~12.288 MHz, 1.7% error)
--    BCLK  = MCLK    / 4   = 3.125 MHz
--    LRCLK = BCLK    / 64  = 48.828 kHz (~48 kHz)
--
--  Forwarded clocks use ODDR primitives to route cleanly off the FPGA.
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;     -- ODDR, BUFG

----------------------------------------------------------------------------
-- Entity definition
----------------------------------------------------------------------------
entity i2s_clock_gen is
    Port (
        -- System clock in
        sysclk_125MHz_i  : in  std_logic;

        -- Forwarded clocks (off-chip, through ODDR)
        mclk_fwd_o       : out std_logic;
        bclk_fwd_o       : out std_logic;
        adc_lrclk_fwd_o  : out std_logic;
        dac_lrclk_fwd_o  : out std_logic;

        -- Internal clocks (on-chip, for I2S logic)
        mclk_o           : out std_logic;
        bclk_o           : out std_logic;
        lrclk_o          : out std_logic);
end i2s_clock_gen;

----------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------
architecture Behavioral of i2s_clock_gen is

----------------------------------------------------------------------------
-- Internal clock signals (outputs of each clock_divider stage)
----------------------------------------------------------------------------
signal mclk  : std_logic := '0';   -- 12.5  MHz
signal bclk  : std_logic := '0';   -- 3.125 MHz
signal lrclk : std_logic := '0';   -- 48.828 kHz

----------------------------------------------------------------------------
-- Clock divider component (defined in clock_divider.vhd)
-- Divides fast_clk_i by CLK_DIV_RATIO, output includes internal BUFG.
----------------------------------------------------------------------------
component clock_divider is
    Generic (CLK_DIV_RATIO : integer := 25_000_000);
    Port (
        fast_clk_i : in  std_logic;
        slow_clk_o : out std_logic);
end component;

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------

----------------------------------------------------------------------------
-- Stage 1: 125 MHz → MCLK (12.5 MHz)  divide by 10
----------------------------------------------------------------------------
mclk_div : clock_divider
    generic map (CLK_DIV_RATIO => 10)
    port map (
        fast_clk_i => sysclk_125MHz_i,
        slow_clk_o => mclk);

----------------------------------------------------------------------------
-- Stage 2: MCLK → BCLK (3.125 MHz)  divide by 4
----------------------------------------------------------------------------
bclk_div : clock_divider
    generic map (CLK_DIV_RATIO => 4)
    port map (
        fast_clk_i => mclk,
        slow_clk_o => bclk);

----------------------------------------------------------------------------
-- Stage 3: BCLK → LRCLK (48.828 kHz)  divide by 64
----------------------------------------------------------------------------
lrclk_div : clock_divider
    generic map (CLK_DIV_RATIO => 64)
    port map (
        fast_clk_i => bclk,
        slow_clk_o => lrclk);

----------------------------------------------------------------------------
-- Drive internal (on-chip) outputs directly from the clock signals.
-- These stay on the clock spine and are used by the transmitter/receiver.
----------------------------------------------------------------------------
mclk_o  <= mclk;
bclk_o  <= bclk;
lrclk_o <= lrclk;

----------------------------------------------------------------------------
-- Forward MCLK off-chip via ODDR
-- D1=1, D2=0 makes the ODDR reproduce the clock waveform at the output pin.
----------------------------------------------------------------------------
oddr_mclk : ODDR
    generic map (
        DDR_CLK_EDGE => "SAME_EDGE",
        INIT         => '0',
        SRTYPE       => "SYNC")
    port map (
        Q  => mclk_fwd_o,
        C  => mclk,
        CE => '1',
        D1 => '1',
        D2 => '0',
        R  => '0',
        S  => '0');

----------------------------------------------------------------------------
-- Forward BCLK off-chip via ODDR
----------------------------------------------------------------------------
oddr_bclk : ODDR
    generic map (
        DDR_CLK_EDGE => "SAME_EDGE",
        INIT         => '0',
        SRTYPE       => "SYNC")
    port map (
        Q  => bclk_fwd_o,
        C  => bclk,
        CE => '1',
        D1 => '1',
        D2 => '0',
        R  => '0',
        S  => '0');

----------------------------------------------------------------------------
-- Forward LRCLK off-chip via ODDR — separate instances for ADC and DAC
-- (both driven by the same lrclk signal)
----------------------------------------------------------------------------
oddr_adc_lrclk : ODDR
    generic map (
        DDR_CLK_EDGE => "SAME_EDGE",
        INIT         => '0',
        SRTYPE       => "SYNC")
    port map (
        Q  => adc_lrclk_fwd_o,
        C  => lrclk,
        CE => '1',
        D1 => '1',
        D2 => '0',
        R  => '0',
        S  => '0');

oddr_dac_lrclk : ODDR
    generic map (
        DDR_CLK_EDGE => "SAME_EDGE",
        INIT         => '0',
        SRTYPE       => "SYNC")
    port map (
        Q  => dac_lrclk_fwd_o,
        C  => lrclk,
        CE => '1',
        D1 => '1',
        D2 => '0',
        R  => '0',
        S  => '0');

----------------------------------------------------------------------------
end Behavioral;
