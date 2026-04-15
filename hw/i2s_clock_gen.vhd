----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
--  ENGS 128
----------------------------------------------------------------------------
--  I2S clock generation for SSM2603 audio codec
--
--  Receives MCLK (12.288 MHz) from the Clocking Wizard in the block design.
--  Divides down to:
--    BCLK  = 3.072 MHz  (MCLK / 4)
--    LRCLK = 48.000 kHz (BCLK / 64)
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity i2s_clock_gen is
    Port (
        mclk_i           : in  std_logic;
        mclk_fwd_o       : out std_logic;
        bclk_fwd_o       : out std_logic;
        adc_lrclk_fwd_o  : out std_logic;
        dac_lrclk_fwd_o  : out std_logic;
        mclk_o           : out std_logic;
        bclk_o           : out std_logic;
        lrclk_o          : out std_logic);
end i2s_clock_gen;

architecture Behavioral of i2s_clock_gen is

constant BCLK_HALF_TC  : integer := 2;
constant LRCLK_HALF_TC : integer := 32;

signal bclk_raw      : std_logic := '0';
signal bclk          : std_logic := '0';
signal lrclk         : std_logic := '0';
signal bclk_counter  : unsigned(0 downto 0) := (others => '0');
signal lrclk_counter : unsigned(4 downto 0) := (others => '0');

begin

-- MCLK -> BCLK divide-by-4
bclk_divider : process(mclk_i)
begin
    if rising_edge(mclk_i) then
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
lrclk_divider : process(bclk)
begin
    if rising_edge(bclk) then
        if lrclk_counter = LRCLK_HALF_TC - 1 then
            lrclk_counter <= (others => '0');
            lrclk         <= not lrclk;
        else
            lrclk_counter <= lrclk_counter + 1;
        end if;
    end if;
end process lrclk_divider;

mclk_o  <= mclk_i;
bclk_o  <= bclk;
lrclk_o <= lrclk;

oddr_mclk : ODDR
    generic map (DDR_CLK_EDGE => "SAME_EDGE", INIT => '0', SRTYPE => "SYNC")
    port map (Q => mclk_fwd_o, C => mclk_i, CE => '1', D1 => '1', D2 => '0', R => '0', S => '0');

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
