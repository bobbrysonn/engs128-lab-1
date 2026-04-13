----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
----------------------------------------------------------------------------
--  ENGS 128
--  Author: Kendall Farnham
----------------------------------------------------------------------------
--  Description: Top-level file for audio codec tone generator and passthrough
--  Target device: Zybo Z7-20
--
--  Task 3: DDS tone generator → I2S transmitter
--  Task 4: adds I2S receiver and passthrough mux (dds_enable_i selects mode)
--
--  Phase increment lookup (12-bit, Fs = 48 kHz, 4096 LUT entries):
--    Left  (C4–C5): 22,25,28,30,33,38,42,45
--    Right (C5–C6): 45,50,56,60,67,75,84,89
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;

----------------------------------------------------------------------------
-- Entity definition
----------------------------------------------------------------------------
entity top_level is
    Port (
        sysclk_i       : in  std_logic;

        -- User controls
        dds_reset_i    : in  std_logic;
        dds_enable_i   : in  std_logic;
        dds_freq_sel_i : in  std_logic_vector(2 downto 0);
        ac_mute_en_i   : in  std_logic;

        -- Audio Codec I2S clocks
        ac_bclk_o      : out std_logic;
        ac_mclk_o      : out std_logic;
        ac_mute_n_o    : out std_logic;    -- Active Low

        -- Audio Codec DAC (audio out)
        ac_dac_data_o  : out std_logic;
        ac_dac_lrclk_o : out std_logic;

        -- Audio Codec ADC (audio in)
        ac_adc_data_i  : in  std_logic;
        ac_adc_lrclk_o : out std_logic);
end top_level;

----------------------------------------------------------------------------
architecture Behavioral of top_level is
----------------------------------------------------------------------------

----------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------
constant AC_DATA_WIDTH   : integer := 24;
constant PHASE_DATA_WIDTH : integer := 12;

----------------------------------------------------------------------------
-- Internal signals
----------------------------------------------------------------------------
-- Clocks
signal mclk_s  : std_logic;
signal bclk_s  : std_logic;
signal lrclk_s : std_logic;

-- DDS phase increments (12-bit)
signal left_phase_inc_s  : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0);
signal right_phase_inc_s : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0);

-- DDS audio data outputs
signal left_dds_data_s  : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
signal right_dds_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0);

-- Audio data routed to the I2S transmitter
-- Task 4: these will be muxed between DDS and receiver data
signal left_tx_data_s  : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
signal right_tx_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0);

-- I2S receiver outputs (Task 4 — declared here so top-level compiles cleanly)
signal left_rx_data_s  : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
signal right_rx_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0);

----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------

-- Clock generation
component i2s_clock_gen is
    Port (
        sysclk_125MHz_i : in  std_logic;
        mclk_fwd_o      : out std_logic;
        bclk_fwd_o      : out std_logic;
        adc_lrclk_fwd_o : out std_logic;
        dac_lrclk_fwd_o : out std_logic;
        mclk_o          : out std_logic;
        bclk_o          : out std_logic;
        lrclk_o         : out std_logic);
end component;

-- I2S transmitter
component i2s_transmitter is
    Generic (AC_DATA_WIDTH : integer := AC_DATA_WIDTH);
    Port (
        bclk_i             : in  std_logic;
        lrclk_i            : in  std_logic;
        left_audio_data_i  : in  std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        right_audio_data_i : in  std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        dac_serial_data_o  : out std_logic);
end component;

-- I2S receiver (Task 4 — declared but not instantiated in Task 3)
component i2s_receiver is
    Generic (AC_DATA_WIDTH : integer := AC_DATA_WIDTH);
    Port (
        bclk_i             : in  std_logic;
        lrclk_i            : in  std_logic;
        left_audio_data_o  : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        right_audio_data_o : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        adc_serial_data_i  : in  std_logic);
end component;

-- DDS tone generator
component dds_controller is
    Generic (
        DDS_DATA_WIDTH   : integer := 24;
        PHASE_DATA_WIDTH : integer := 12);
    Port (
        clk_i       : in  std_logic;
        enable_i    : in  std_logic;
        reset_i     : in  std_logic;
        phase_inc_i : in  std_logic_vector(PHASE_DATA_WIDTH-1 downto 0);
        data_o      : out std_logic_vector(DDS_DATA_WIDTH-1 downto 0));
end component;

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------

----------------------------------------------------------------------------
-- Clock generation
----------------------------------------------------------------------------
clk_gen : i2s_clock_gen
    port map (
        sysclk_125MHz_i => sysclk_i,
        mclk_fwd_o      => ac_mclk_o,
        bclk_fwd_o      => ac_bclk_o,
        adc_lrclk_fwd_o => ac_adc_lrclk_o,
        dac_lrclk_fwd_o => ac_dac_lrclk_o,
        mclk_o          => mclk_s,
        bclk_o          => bclk_s,
        lrclk_o         => lrclk_s);

----------------------------------------------------------------------------
-- DDS tone generator — left audio channel (C4–C5)
----------------------------------------------------------------------------
dds_left : dds_controller
    generic map (
        DDS_DATA_WIDTH   => AC_DATA_WIDTH,
        PHASE_DATA_WIDTH => PHASE_DATA_WIDTH)
    port map (
        clk_i       => lrclk_s,
        enable_i    => dds_enable_i,
        reset_i     => dds_reset_i,
        phase_inc_i => left_phase_inc_s,
        data_o      => left_dds_data_s);

----------------------------------------------------------------------------
-- DDS tone generator — right audio channel (C5–C6)
----------------------------------------------------------------------------
dds_right : dds_controller
    generic map (
        DDS_DATA_WIDTH   => AC_DATA_WIDTH,
        PHASE_DATA_WIDTH => PHASE_DATA_WIDTH)
    port map (
        clk_i       => lrclk_s,
        enable_i    => dds_enable_i,
        reset_i     => dds_reset_i,
        phase_inc_i => right_phase_inc_s,
        data_o      => right_dds_data_s);

----------------------------------------------------------------------------
-- I2S transmitter
----------------------------------------------------------------------------
i2s_tx : i2s_transmitter
    generic map (AC_DATA_WIDTH => AC_DATA_WIDTH)
    port map (
        bclk_i             => bclk_s,
        lrclk_i            => lrclk_s,
        left_audio_data_i  => left_tx_data_s,
        right_audio_data_i => right_tx_data_s,
        dac_serial_data_o  => ac_dac_data_o);

-- -------------------------------------------------------------------------
-- I2S receiver (Task 4)
-- -------------------------------------------------------------------------
-- Uncomment and implement i2s_receiver.vhd for Task 4 passthrough test
-- i2s_rx : i2s_receiver
--     generic map (AC_DATA_WIDTH => AC_DATA_WIDTH)
--     port map (
--         bclk_i             => bclk_s,
--         lrclk_i            => lrclk_s,
--         adc_serial_data_i  => ac_adc_data_i,
--         left_audio_data_o  => left_rx_data_s,
--         right_audio_data_o => right_rx_data_s);

-- Tie receiver outputs to zero until Task 4
left_rx_data_s  <= (others => '0');
right_rx_data_s <= (others => '0');

----------------------------------------------------------------------------
-- Audio source mux
-- dds_enable_i = '1' : transmit DDS tone (Task 3)
-- dds_enable_i = '0' : transmit ADC passthrough (Task 4)
----------------------------------------------------------------------------
left_tx_data_s  <= left_dds_data_s  when dds_enable_i = '1' else left_rx_data_s;
right_tx_data_s <= right_dds_data_s when dds_enable_i = '1' else right_rx_data_s;

----------------------------------------------------------------------------
-- Mute control (active low)
----------------------------------------------------------------------------
ac_mute_n_o <= not ac_mute_en_i;

----------------------------------------------------------------------------
-- Phase increment lookup tables
-- Left channel: C4(000) → C5(111)
----------------------------------------------------------------------------
with dds_freq_sel_i select left_phase_inc_s <=
    x"016" when "000",   -- C4  261.63 Hz  inc=22
    x"019" when "001",   -- D4  293.66 Hz  inc=25
    x"01C" when "010",   -- E4  329.63 Hz  inc=28
    x"01E" when "011",   -- F4  349.23 Hz  inc=30
    x"021" when "100",   -- G4  392.00 Hz  inc=33
    x"026" when "101",   -- A4  440.00 Hz  inc=38
    x"02A" when "110",   -- B4  493.88 Hz  inc=42
    x"02D" when others;  -- C5  523.25 Hz  inc=45

-- Right channel: C5(000) → C6(111)
with dds_freq_sel_i select right_phase_inc_s <=
    x"02D" when "000",   -- C5  523.25 Hz  inc=45
    x"032" when "001",   -- D5  587.33 Hz  inc=50
    x"038" when "010",   -- E5  659.26 Hz  inc=56
    x"03C" when "011",   -- F5  698.46 Hz  inc=60
    x"043" when "100",   -- G5  784.00 Hz  inc=67
    x"04B" when "101",   -- A5  880.00 Hz  inc=75
    x"054" when "110",   -- B5  987.77 Hz  inc=84
    x"059" when others;  -- C6 1046.50 Hz  inc=89

----------------------------------------------------------------------------
end Behavioral;
