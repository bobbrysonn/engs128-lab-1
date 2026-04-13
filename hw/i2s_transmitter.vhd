----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
----------------------------------------------------------------------------
--  ENGS 128
--  Author: Kendall Farnham
----------------------------------------------------------------------------
--  Description: I2S transmitter for SSM2603 audio codec
--
--  Frame structure per channel (32 BCLK cycles):
--    Cycle 0      : X delay (don't care, output '0')
--    Cycles 1-24  : data bits, MSB first
--    Cycles 25-31 : zero padding
--
--  LRCLK low  = left  channel
--  LRCLK high = right channel
--
--  Data is driven on BCLK falling edges (sampled by codec on rising edges).
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------
-- Entity definition
----------------------------------------------------------------------------
entity i2s_transmitter is
    Generic (AC_DATA_WIDTH : integer := 24);
    Port (
        -- Timing
        bclk_i  : in std_logic;
        lrclk_i : in std_logic;

        -- Data
        left_audio_data_i  : in  std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        right_audio_data_i : in  std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        dac_serial_data_o  : out std_logic);
end i2s_transmitter;

----------------------------------------------------------------------------
architecture Behavioral of i2s_transmitter is
----------------------------------------------------------------------------

----------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------
-- One I2S frame per channel = 1 X-delay + AC_DATA_WIDTH data + 7 padding
-- = 1 + 24 + 7 = 32 BCLK cycles
constant FRAME_BITS   : integer := AC_DATA_WIDTH + 8;   -- 32
constant PADDING_BITS : integer := FRAME_BITS - AC_DATA_WIDTH - 1;  -- 7

----------------------------------------------------------------------------
-- FSM
----------------------------------------------------------------------------
type state_type is (IDLE, SHIFT);
signal state : state_type := IDLE;

----------------------------------------------------------------------------
-- Datapath signals
----------------------------------------------------------------------------
-- Shift register holds the bits sent after the I2S delay slot:
-- data (24b) & zeros (7b) & trailing fill bit = 32 bits total storage
signal shift_reg  : std_logic_vector(FRAME_BITS-1 downto 0) := (others => '0');
signal bit_count  : integer range 0 to FRAME_BITS-1 := 0;

-- Registered LRCLK for edge detection (sampled on falling BCLK)
signal lrclk_prev : std_logic := '0';

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------

----------------------------------------------------------------------------
-- I2S transmit process — all activity on falling BCLK edge
-- (codec samples PBDAT on rising edge, so we drive on falling for maximum
-- setup/hold margin)
----------------------------------------------------------------------------
transmit : process(bclk_i)
begin
    if falling_edge(bclk_i) then

        case state is

            ------------------------------------------------------------
            -- IDLE: wait for an LRCLK edge to start a new frame
            ------------------------------------------------------------
            when IDLE =>
                dac_serial_data_o <= '0';

                -- Register LRCLK only in IDLE so edges that occur during
                -- SHIFT are not consumed before we return here to check them.
                lrclk_prev <= lrclk_i;

                -- LRCLK rising edge → right channel frame starts.
                -- This falling BCLK is the mandatory I2S one-bit delay, so
                -- preload the remaining 31 bits to send on subsequent BCLKs.
                if lrclk_i = '1' and lrclk_prev = '0' then
                    shift_reg <= right_audio_data_i &
                                 std_logic_vector(to_unsigned(0, PADDING_BITS)) &
                                 '0';
                    bit_count <= 1;
                    state     <= SHIFT;

                -- LRCLK falling edge → left channel frame starts.
                elsif lrclk_i = '0' and lrclk_prev = '1' then
                    shift_reg <= left_audio_data_i &
                                 std_logic_vector(to_unsigned(0, PADDING_BITS)) &
                                 '0';
                    bit_count <= 1;
                    state     <= SHIFT;
                end if;

            ------------------------------------------------------------
            -- SHIFT: clock out FRAME_BITS bits, MSB first
            --   bit 0     = '0'  (X delay cycle)
            --   bits 1-24 = data MSB → LSB
            --   bits 25-31 = '0' (padding)
            ------------------------------------------------------------
            when SHIFT =>
                -- Drive MSB onto the serial line
                dac_serial_data_o <= shift_reg(FRAME_BITS-1);
                -- Shift left, filling vacated LSB with '0'
                shift_reg <= shift_reg(FRAME_BITS-2 downto 0) & '0';

                if bit_count = FRAME_BITS-1 then
                    bit_count <= 0;
                    state     <= IDLE;
                else
                    bit_count <= bit_count + 1;
                end if;

        end case;
    end if;
end process transmit;

----------------------------------------------------------------------------
end Behavioral;
