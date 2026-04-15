----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
--  ENGS 128
----------------------------------------------------------------------------
--  I2S clock generation for SSM2603 audio codec
--
--  MCLK  = 12.288 MHz  (clk_wiz_0 clk_out1, from 125 MHz sysclk)
--  BCLK  =  3.072 MHz  (MCLK / 4)
--  LRCLK = 48.000 kHz  (BCLK / 64)
--
--  Vivado: create Clocking Wizard IP named clk_wiz_0
--    clk_in1  = 125 MHz, clk_out1 = 12.288 MHz (single output)
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity i2s_clock_gen is
    Port (
        sysclk_125MHz_i  : in  std_logic;
        mclk_fwd_o       : out std_logic;
        bclk_fwd_o       : out std_logic;
        adc_lrclk_fwd_o  : out std_logic;
        dac_lrclk_fwd_o  : out std_logic;
        mclk_o           : out std_logic;
        bclk_o           : out std_logic;
        lrclk_o          : out std_logic);
end i2s_clock_gen;

architecture Behavioral of i2s_clock_gen is

-- MCLK -> BCLK: toggle every 2 MCLK cycles (divide-by-4)
constant BCLK_HALF_TC   : integer := 2;
-- BCLK -> LRCLK: toggle every 32 BCLK cycles (divide-by-64)
constant LRCLK_HALF_TC  : integer := 32;

signal mclk     : std_logic := '0';
signal bclk_raw : std_logic := '0';
signal bclk     : std_logic := '0';
signal lrclk    : std_logic := '0';
signal locked   : std_logic := '0';

signal bclk_counter  : unsigned(0 downto 0) := (others => '0');
signal lrclk_counter : unsigned(4 downto 0) := (others => '0');

component clk_wiz_0 is
    port (
        clk_out1 : out std_logic;
        reset    : in  std_logic;
        locked   : out std_logic;
        clk_in1  : in  std_logic);
end component;

begin

audio_clk_wiz : clk_wiz_0
    port map (
        clk_out1 => mclk,
        reset    => '0',
        locked   => locked,
        clk_in1  => sysclk_125MHz_i);

-- MCLK -> BCLK divide-by-4
bclk_divider : process(mclk, locked)
begin
    if locked = '0' then
        bclk_counter <= (others => '0');
        bclk_raw     <= '0';
    elsif rising_edge(mclk) then
        if bclk_counter = BCLK_HALF_TC - 1 then
            bclk_counter <= (others => '0');
            bclk_raw     <= not bclk_raw;
        else
            bclk_counter <= bclk_counter + 1;
        end if;
    end if;
end process bclk_divider;

bclk_bufg : BUFG
    port map (I => bclk_raw, O => bclk);

-- BCLK -> LRCLK divide-by-64
lrclk_divider : process(bclk, locked)
begin
    if locked = '0' then
        lrclk_counter <= (others => '0');
        lrclk         <= '0';
    elsif rising_edge(bclk) then
        if lrclk_counter = LRCLK_HALF_TC - 1 then
            lrclk_counter <= (others => '0');
            lrclk         <= not lrclk;
        else
            lrclk_counter <= lrclk_counter + 1;
        end if;
    end if;
end process lrclk_divider;

mclk_o  <= mclk;
bclk_o  <= bclk;
lrclk_o <= lrclk;

oddr_mclk : ODDR
    generic map (DDR_CLK_EDGE => "SAME_EDGE", INIT => '0', SRTYPE => "SYNC")
    port map (Q => mclk_fwd_o, C => mclk, CE => '1', D1 => '1', D2 => '0', R => '0', S => '0');

oddr_bclk : ODDR
    generic map (DDR_CLK_EDGE => "SAME_EDGE", INIT => '0', SRTYPE => "SYNC")
    port map (Q => bclk_fwd_o, C => bclk, CE => '1', D1 => '1', D2 => '0', R => '0', S => '0');

oddr_adc_lrclk : ODDR
    generic map (DDR_CLK_EDGE => "SAME_EDGE", INIT => '0', SRTYPE => "SYNC")
    port map (Q => adc_lrclk_fwd_o, C => lrclk, CE => '1', D1 => '1', D2 => '0', R => '0', S => '0');

oddr_dac_lrclk : ODDR
    generic map (DDR_CLK_EDGE => "SAME_EDGE", INIT => '0', SRTYPE => "SYNC")
    port map (Q => dac_lrclk_fwd_o, C => lrclk, CE => '1', D1 => '1', D2 => '0', R => '0', S => '0');

end Behavioral;
