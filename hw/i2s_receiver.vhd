----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
----------------------------------------------------------------------------
--  ENGS 128
--  Author: Kendall Farnham
----------------------------------------------------------------------------
--  Description: I2S receiver for SSM2603 audio codec
--
--  Frame structure per channel (32 BCLK cycles):
--    Cycle 0      : X delay (ignored)
--    Cycles 1-24  : data bits, MSB first
--    Cycles 25-31 : zero / don't care padding (ignored)
--
--  LRCLK low  = left  channel
--  LRCLK high = right channel
--
--  Data is sampled on BCLK rising edges after being driven on falling edges.
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------
-- Entity definition
----------------------------------------------------------------------------
entity i2s_receiver is
    Generic (AC_DATA_WIDTH : integer := 24);
    Port (
        -- Timing
        bclk_i    : in  std_logic;
        lrclk_i   : in  std_logic;

        -- Data
        left_audio_data_o  : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        right_audio_data_o : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        adc_serial_data_i  : in  std_logic);
end i2s_receiver;

----------------------------------------------------------------------------
architecture Behavioral of i2s_receiver is
----------------------------------------------------------------------------

----------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------
constant FRAME_BITS : integer := AC_DATA_WIDTH + 8;   -- 32

----------------------------------------------------------------------------
-- FSM
----------------------------------------------------------------------------
type state_type is (IDLE, SHIFT);
signal state : state_type := IDLE;

----------------------------------------------------------------------------
-- Datapath signals
----------------------------------------------------------------------------
signal shift_reg          : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal bit_count          : integer range 0 to FRAME_BITS-1 := 0;
signal lrclk_prev         : std_logic := '0';
signal left_audio_data_s  : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal right_audio_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
left_audio_data_o  <= left_audio_data_s;
right_audio_data_o <= right_audio_data_s;

----------------------------------------------------------------------------
-- I2S receive process
-- Detect an LRCLK edge, skip the mandatory I2S delay slot, then capture
-- 24 MSB-first data bits on BCLK rising edges.
----------------------------------------------------------------------------
receive : process(bclk_i)
    variable next_word : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
begin
    if rising_edge(bclk_i) then
        case state is

            ------------------------------------------------------------
            -- IDLE: wait for an LRCLK edge to mark the start of a frame
            ------------------------------------------------------------
            when IDLE =>
                lrclk_prev <= lrclk_i;

                if lrclk_i /= lrclk_prev then
                    shift_reg <= (others => '0');
                    bit_count <= 0;
                    state     <= SHIFT;
                end if;

            ------------------------------------------------------------
            -- SHIFT:
            --   bits 0-23  = captured sample (MSB first)
            --   bits 24-31 = padding / don't care (ignored)
            --
            --  The LRCLK edge is detected at R0 (rising BCLK halfway through
            --  the I2S delay slot).  By R1 (bit_count=0) the delay slot is
            --  over and the codec has already driven the MSB, so capture
            --  begins immediately at bit_count=0.
            ------------------------------------------------------------
            when SHIFT =>
                if bit_count <= AC_DATA_WIDTH - 1 then
                    next_word := shift_reg(AC_DATA_WIDTH-2 downto 0) & adc_serial_data_i;
                    shift_reg <= next_word;

                    if bit_count = AC_DATA_WIDTH - 1 then
                        if lrclk_i = '0' then
                            left_audio_data_s <= next_word;
                        else
                            right_audio_data_s <= next_word;
                        end if;
                    end if;
                end if;

                if bit_count = FRAME_BITS-1 then
                    bit_count <= 0;
                    state     <= IDLE;
                else
                    bit_count <= bit_count + 1;
                end if;

        end case;
    end if;
end process receive;

----------------------------------------------------------------------------
end Behavioral;
