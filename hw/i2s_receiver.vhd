----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
----------------------------------------------------------------------------
--  ENGS 128
--  Author: Kendall Farnham
----------------------------------------------------------------------------
--  Description: I2S receiver for SSM2603 audio codec
--
--  Frame structure per channel (32 BCLK cycles):
--    Cycle 0      : delay slot (LRCLK just transitioned; data line still old)
--    Cycles 1-24  : data bits, MSB first
--    Cycles 25-31 : zero / don't care padding (ignored)
--
--  LRCLK low  = left  channel
--  LRCLK high = right channel
--
--  Data is sampled on BCLK rising edges after being driven on falling edges.
--
--  6-state FSM (per teacher reference):
--    IDLE1  : wait for LRCLK rising edge (right-channel frame about to start)
--    LOADR  : capture right-channel MSB (bit 0); delay slot has just passed
--    SHIFTR : capture bits 1-23; save word when done; -> IDLE2
--    IDLE2  : wait for LRCLK falling edge (left-channel frame about to start)
--    LOADL  : capture left-channel MSB
--    SHIFTL : capture bits 1-23; save word when done; -> IDLE1
--
--  Timing note: clock_divider is rising-edge triggered, so LRCLK transitions
--  ON a BCLK rising edge.  The FSM sees the new LRCLK value at that edge and
--  advances to LOAD* in the SAME clock cycle.  The codec drives the channel
--  MSB on the immediately following BCLK falling edge, so the LOAD* state
--  (which executes on the NEXT rising edge) captures the correct first bit.
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
-- FSM
----------------------------------------------------------------------------
type state_type is (IDLE1, LOADR, SHIFTR, IDLE2, LOADL, SHIFTL);
signal state : state_type := IDLE1;

----------------------------------------------------------------------------
-- Datapath signals
----------------------------------------------------------------------------
signal shift_reg          : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal bit_count          : integer range 0 to AC_DATA_WIDTH-1 := 0;
signal left_audio_data_s  : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal right_audio_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
left_audio_data_o  <= left_audio_data_s;
right_audio_data_o <= right_audio_data_s;

----------------------------------------------------------------------------
-- I2S receive process
-- All activity on BCLK rising edges.
-- LRCLK level is checked directly (no separate edge-detect register) because
-- the 6-state FSM naturally arrives at each IDLE state with LRCLK in the
-- opposite polarity from the transition it is waiting for.
----------------------------------------------------------------------------
receive : process(bclk_i)
    variable next_word : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
begin
    if rising_edge(bclk_i) then
        case state is

            ----------------------------------------------------------------
            -- IDLE1: LRCLK is low (left frame running or just finished).
            -- Wait for LRCLK to go high (right-channel frame begins).
            -- This rising edge IS the I2S delay slot for the right channel;
            -- the codec will drive the right MSB on the next falling BCLK.
            ----------------------------------------------------------------
            when IDLE1 =>
                if lrclk_i = '1' then
                    state <= LOADR;
                end if;

            ----------------------------------------------------------------
            -- LOADR: delay slot has just passed.
            -- The codec drove the right-channel MSB on the preceding falling
            -- BCLK, so it is stable now.  Capture it into the LSB of the
            -- shift register and start the bit counter at 1.
            ----------------------------------------------------------------
            when LOADR =>
                shift_reg <= (AC_DATA_WIDTH-2 downto 0 => '0') & adc_serial_data_i;
                bit_count <= 1;
                state     <= SHIFTR;

            ----------------------------------------------------------------
            -- SHIFTR: shift in bits 1-23 (MSB first, new bit at LSB).
            -- At bit_count = AC_DATA_WIDTH-1 (= 23), all 24 bits have been
            -- captured; latch to right output and move to IDLE2.
            ----------------------------------------------------------------
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

            ----------------------------------------------------------------
            -- IDLE2: LRCLK is high (right frame still running, padding bits).
            -- Wait for LRCLK to go low (left-channel frame begins).
            -- This falling edge IS the I2S delay slot for the left channel.
            ----------------------------------------------------------------
            when IDLE2 =>
                if lrclk_i = '0' then
                    state <= LOADL;
                end if;

            ----------------------------------------------------------------
            -- LOADL: delay slot has just passed for left channel.
            -- Capture left-channel MSB into the shift register.
            ----------------------------------------------------------------
            when LOADL =>
                shift_reg <= (AC_DATA_WIDTH-2 downto 0 => '0') & adc_serial_data_i;
                bit_count <= 1;
                state     <= SHIFTL;

            ----------------------------------------------------------------
            -- SHIFTL: shift in bits 1-23 for the left channel.
            -- At bit_count = AC_DATA_WIDTH-1, latch to left output and
            -- return to IDLE1.
            ----------------------------------------------------------------
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

----------------------------------------------------------------------------
end Behavioral;
