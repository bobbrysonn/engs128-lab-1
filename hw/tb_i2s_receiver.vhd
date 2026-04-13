----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
----------------------------------------------------------------------------
--  ENGS 128
--  Author: Kendall Farnham
----------------------------------------------------------------------------
--  Description: Pass-through testbench for the I2S receiver
--
--  Task 4 verification path:
--    DDS -> I2S Transmitter -> I2S Receiver
--
--  The receiver should reconstruct the same left/right samples that were
--  presented to the transmitter, after the expected serial-frame latency.
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------
-- Entity definition
----------------------------------------------------------------------------
entity tb_i2s_receiver is
end tb_i2s_receiver;

----------------------------------------------------------------------------
architecture testbench of tb_i2s_receiver is
----------------------------------------------------------------------------

----------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------
constant CLOCK_PERIOD      : time := 8 ns;   -- 125 MHz system clock
constant AC_DATA_WIDTH     : integer := 24;
constant PHASE_DATA_WIDTH  : integer := 12;
constant FRAME_BITS        : integer := AC_DATA_WIDTH + 8;   -- 32

constant LEFT_INC_C4  : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := x"016";
constant LEFT_INC_A4  : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := x"026";
constant RIGHT_INC_C5 : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := x"02D";
constant RIGHT_INC_A5 : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := x"04B";

----------------------------------------------------------------------------
-- DUT / test signals
----------------------------------------------------------------------------
signal clk               : std_logic := '0';
signal bclk              : std_logic := '0';
signal lrclk             : std_logic := '0';
signal serial_data       : std_logic := '0';
signal dds_enable        : std_logic := '0';
signal dds_reset         : std_logic := '1';
signal left_phase_inc    : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := LEFT_INC_C4;
signal right_phase_inc   : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := RIGHT_INC_C5;
signal left_audio_data_tx  : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal right_audio_data_tx : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal left_audio_data_rx  : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
signal right_audio_data_rx : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');

----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------
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

component i2s_transmitter is
    Generic (AC_DATA_WIDTH : integer := 24);
    Port (
        bclk_i             : in  std_logic;
        lrclk_i            : in  std_logic;
        left_audio_data_i  : in  std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        right_audio_data_i : in  std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        dac_serial_data_o  : out std_logic);
end component;

component i2s_receiver is
    Generic (AC_DATA_WIDTH : integer := 24);
    Port (
        bclk_i             : in  std_logic;
        lrclk_i            : in  std_logic;
        left_audio_data_o  : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        right_audio_data_o : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        adc_serial_data_i  : in  std_logic);
end component;

----------------------------------------------------------------------------
-- Scoreboard signals
----------------------------------------------------------------------------
type monitor_state_type is (IDLE, SHIFT);
signal monitor_state : monitor_state_type := IDLE;
signal monitor_count : integer range 0 to FRAME_BITS-1 := 0;
signal lrclk_prev    : std_logic := '0';

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------

----------------------------------------------------------------------------
-- Clock generation
----------------------------------------------------------------------------
clock_gen_process : process
begin
    clk <= '0';
    wait for CLOCK_PERIOD / 2;
    loop
        clk <= not clk;
        wait for CLOCK_PERIOD / 2;
    end loop;
end process clock_gen_process;

clk_gen : i2s_clock_gen
    port map (
        sysclk_125MHz_i => clk,
        mclk_fwd_o      => open,
        bclk_fwd_o      => open,
        adc_lrclk_fwd_o => open,
        dac_lrclk_fwd_o => open,
        mclk_o          => open,
        bclk_o          => bclk,
        lrclk_o         => lrclk);

----------------------------------------------------------------------------
-- DDS sample sources
----------------------------------------------------------------------------
dds_left : dds_controller
    generic map (
        DDS_DATA_WIDTH   => AC_DATA_WIDTH,
        PHASE_DATA_WIDTH => PHASE_DATA_WIDTH)
    port map (
        clk_i       => lrclk,
        enable_i    => dds_enable,
        reset_i     => dds_reset,
        phase_inc_i => left_phase_inc,
        data_o      => left_audio_data_tx);

dds_right : dds_controller
    generic map (
        DDS_DATA_WIDTH   => AC_DATA_WIDTH,
        PHASE_DATA_WIDTH => PHASE_DATA_WIDTH)
    port map (
        clk_i       => lrclk,
        enable_i    => dds_enable,
        reset_i     => dds_reset,
        phase_inc_i => right_phase_inc,
        data_o      => right_audio_data_tx);

----------------------------------------------------------------------------
-- I2S transmit / receive chain
----------------------------------------------------------------------------
i2s_tx : i2s_transmitter
    generic map (AC_DATA_WIDTH => AC_DATA_WIDTH)
    port map (
        bclk_i             => bclk,
        lrclk_i            => lrclk,
        left_audio_data_i  => left_audio_data_tx,
        right_audio_data_i => right_audio_data_tx,
        dac_serial_data_o  => serial_data);

i2s_rx : i2s_receiver
    generic map (AC_DATA_WIDTH => AC_DATA_WIDTH)
    port map (
        bclk_i             => bclk,
        lrclk_i            => lrclk,
        left_audio_data_o  => left_audio_data_rx,
        right_audio_data_o => right_audio_data_rx,
        adc_serial_data_i  => serial_data);

----------------------------------------------------------------------------
-- Scoreboard
-- Check one BCLK after the receiver latches each sample so the registered
-- outputs have time to update.
----------------------------------------------------------------------------
monitor_proc : process(bclk)
begin
    if rising_edge(bclk) then
        case monitor_state is
            when IDLE =>
                lrclk_prev <= lrclk;

                if lrclk /= lrclk_prev then
                    monitor_count <= 0;
                    monitor_state <= SHIFT;
                end if;

            when SHIFT =>
                if monitor_count = AC_DATA_WIDTH + 1 then
                    if lrclk = '0' then
                        assert left_audio_data_rx = left_audio_data_tx
                            report "Left-channel passthrough mismatch"
                            severity error;
                    else
                        assert right_audio_data_rx = right_audio_data_tx
                            report "Right-channel passthrough mismatch"
                            severity error;
                    end if;
                end if;

                if monitor_count = FRAME_BITS-1 then
                    monitor_count <= 0;
                    monitor_state <= IDLE;
                else
                    monitor_count <= monitor_count + 1;
                end if;
        end case;
    end if;
end process monitor_proc;

----------------------------------------------------------------------------
-- Stimulus
----------------------------------------------------------------------------
stim_proc : process
begin
    dds_enable      <= '0';
    dds_reset       <= '1';
    left_phase_inc  <= LEFT_INC_C4;
    right_phase_inc <= RIGHT_INC_C5;

    wait for 200 us;

    dds_reset  <= '0';
    dds_enable <= '1';
    wait for 8 ms;

    left_phase_inc  <= LEFT_INC_A4;
    right_phase_inc <= RIGHT_INC_A5;
    wait for 8 ms;

    dds_enable <= '0';
    wait for 2 ms;

    dds_enable <= '1';
    wait for 8 ms;

    std.env.stop;
end process stim_proc;

----------------------------------------------------------------------------
end testbench;
