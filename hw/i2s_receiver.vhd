----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
--  ENGS 128 | Author: Kendall Farnham
----------------------------------------------------------------------------
--  I2S receiver for SSM2603 audio codec
--
--  Frame: 32 BCLK cycles per channel
--    Cycle 0     : delay slot (LRCLK just transitioned)
--    Cycles 1-24 : data bits MSB first
--    Cycles 25-31: padding (ignored)
--
--  LRCLK low = left, high = right. Data sampled on BCLK rising edges.
--
--  6-state FSM:
--    IDLE1  -> LOADR  : LRCLK rising edge  (right frame)
--    LOADR  -> SHIFTR : capture right MSB
--    SHIFTR -> IDLE2  : shift 23 more bits, latch right word
--    IDLE2  -> LOADL  : LRCLK falling edge (left frame)
--    LOADL  -> SHIFTL : capture left MSB
--    SHIFTL -> IDLE1  : shift 23 more bits, latch left word
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2s_receiver is
    Generic (AC_DATA_WIDTH : integer := 24);
    Port (
        bclk_i             : in  std_logic;
        lrclk_i            : in  std_logic;
        left_audio_data_o  : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        right_audio_data_o : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        adc_serial_data_i  : in  std_logic);
end i2s_receiver;

architecture Behavioral of i2s_receiver is

type state_type is (IDLE1, LOADR, SHIFTR, IDLE2, LOADL, SHIFTL);
signal state : state_type := IDLE1;

signal shift_reg          : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal bit_count          : integer range 0 to AC_DATA_WIDTH-1 := 0;
signal lrclk_prev         : std_logic := '0';
signal left_audio_data_s  : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal right_audio_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');

begin

left_audio_data_o  <= left_audio_data_s;
right_audio_data_o <= right_audio_data_s;

receive : process(bclk_i)
    variable next_word : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
begin
    if rising_edge(bclk_i) then
        lrclk_prev <= lrclk_i;

        case state is
            when IDLE1 =>
                if lrclk_i = '1' and lrclk_prev = '0' then
                    state <= LOADR;
                end if;

            when LOADR =>
                shift_reg <= (AC_DATA_WIDTH-2 downto 0 => '0') & adc_serial_data_i;
                bit_count <= 1;
                state     <= SHIFTR;

            when SHIFTR =>
                next_word := shift_reg(AC_DATA_WIDTH-2 downto 0) & adc_serial_data_i;
                shift_reg <= next_word;
                if bit_count = AC_DATA_WIDTH - 1 then
                    right_audio_data_s <= next_word;
                    bit_count <= 0;
                    state     <= IDLE2;
                else
                    bit_count <= bit_count + 1;
                end if;

            when IDLE2 =>
                if lrclk_i = '0' and lrclk_prev = '1' then
                    state <= LOADL;
                end if;

            when LOADL =>
                shift_reg <= (AC_DATA_WIDTH-2 downto 0 => '0') & adc_serial_data_i;
                bit_count <= 1;
                state     <= SHIFTL;

            when SHIFTL =>
                next_word := shift_reg(AC_DATA_WIDTH-2 downto 0) & adc_serial_data_i;
                shift_reg <= next_word;
                if bit_count = AC_DATA_WIDTH - 1 then
                    left_audio_data_s <= next_word;
                    bit_count <= 0;
                    state     <= IDLE1;
                else
                    bit_count <= bit_count + 1;
                end if;
        end case;
    end if;
end process receive;

end Behavioral;
