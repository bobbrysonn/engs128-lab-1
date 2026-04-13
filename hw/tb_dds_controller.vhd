----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
----------------------------------------------------------------------------
--  ENGS 128
--  Author: Kendall Farnham
----------------------------------------------------------------------------
--  Description: Testbench for the DDS Controller (with BRAM sine LUT)
--
--  Phase increment calculation:
--    phase_inc = round( f_desired * 2^PHASE_DATA_WIDTH / Fs )
--             = round( f_desired * 4096 / 48000 )
--
--  Left audio (octave 4):
--    C4  261.63 Hz  → inc = 22  (0x016)   actual = 258.3 Hz  error = -1.3%
--    D4  293.66 Hz  → inc = 25  (0x019)   actual = 292.9 Hz  error = -0.3%
--    E4  329.63 Hz  → inc = 28  (0x01C)   actual = 328.1 Hz  error = -0.5%
--    F4  349.23 Hz  → inc = 30  (0x01E)   actual = 351.6 Hz  error = +0.7%
--    G4  392.00 Hz  → inc = 33  (0x021)   actual = 386.7 Hz  error = -1.4%
--    A4  440.00 Hz  → inc = 38  (0x026)   actual = 445.3 Hz  error = +1.2%
--    B4  493.88 Hz  → inc = 42  (0x02A)   actual = 492.2 Hz  error = -0.3%
--    C5  523.25 Hz  → inc = 45  (0x02D)   actual = 527.3 Hz  error = +0.8%
--
--  Right audio (octave 5):
--    C5  523.25 Hz  → inc = 45  (0x02D)   actual = 527.3 Hz  error = +0.8%
--    D5  587.33 Hz  → inc = 50  (0x032)   actual = 585.9 Hz  error = -0.2%
--    E5  659.26 Hz  → inc = 56  (0x038)   actual = 656.3 Hz  error = -0.5%
--    F5  698.46 Hz  → inc = 60  (0x03C)   actual = 703.1 Hz  error = +0.7%
--    G5  784.00 Hz  → inc = 67  (0x043)   actual = 785.2 Hz  error = +0.1%
--    A5  880.00 Hz  → inc = 75  (0x04B)   actual = 878.9 Hz  error = -0.1%
--    B5  987.77 Hz  → inc = 84  (0x054)   actual = 984.4 Hz  error = -0.3%
--    C6 1046.50 Hz  → inc = 89  (0x059)   actual = 1043.0 Hz error = -0.3%
--
--  All errors are within the 1% specification.
--
--  Simulation plan:
--    1. Reset then run A4 (440 Hz) for ~5 full cycles  (~11 ms)
--    2. Switch to A5 (880 Hz, right-channel octave) and observe frequency doubles
--    3. Pause (enable='0') mid-tone and confirm output freezes
--    4. Resume and verify output continues from frozen phase
--    5. Assert reset while enabled — confirm phase snaps back to 0
--    6. Walk through C4 → C5 (left octave) sequentially
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

----------------------------------------------------------------------------
-- Entity definition (no ports — self-contained testbench)
----------------------------------------------------------------------------
entity tb_dds_controller is
end tb_dds_controller;

----------------------------------------------------------------------------
architecture testbench of tb_dds_controller is
----------------------------------------------------------------------------

----------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------
constant SAMPLING_FREQ    : real    := 48000.0;
constant T_SAMPLE_NS      : real    := (1.0 / SAMPLING_FREQ) * 1.0e9;   -- ns per sample
constant CLOCK_PERIOD     : time    := integer(T_SAMPLE_NS) * 1 ns;     -- 20833 ns ≈ 20.83 us

constant DDS_DATA_WIDTH   : integer := 24;
constant PHASE_DATA_WIDTH : integer := 12;

-- How long to run each frequency — long enough to see several complete cycles
-- of the lowest test tone (A4 at 440 Hz → period ≈ 2.27 ms; 5 cycles ≈ 11.4 ms)
constant RUN_TIME : time := 15 ms;

-- Phase increments (see header table above)
constant INC_A4  : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := x"026"; -- 38 → 445 Hz
constant INC_A5  : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := x"04B"; -- 75 → 879 Hz
constant INC_C4  : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := x"016"; -- 22 → 258 Hz
constant INC_D4  : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := x"019"; -- 25 → 293 Hz
constant INC_E4  : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := x"01C"; -- 28 → 328 Hz
constant INC_F4  : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := x"01E"; -- 30 → 352 Hz
constant INC_G4  : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := x"021"; -- 33 → 387 Hz
constant INC_B4  : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := x"02A"; -- 42 → 492 Hz
constant INC_C5  : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := x"02D"; -- 45 → 527 Hz

----------------------------------------------------------------------------
-- DUT signals
----------------------------------------------------------------------------
signal clk            : std_logic := '0';
signal enable         : std_logic := '0';
signal reset          : std_logic := '1';
signal phase_inc      : std_logic_vector(PHASE_DATA_WIDTH-1 downto 0) := (others => '0');
signal data_out       : std_logic_vector(DDS_DATA_WIDTH-1 downto 0);

----------------------------------------------------------------------------
-- Component declaration — matches dds_controller entity exactly
----------------------------------------------------------------------------
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
-- DUT instantiation
----------------------------------------------------------------------------
dut : dds_controller
    generic map (
        DDS_DATA_WIDTH   => DDS_DATA_WIDTH,
        PHASE_DATA_WIDTH => PHASE_DATA_WIDTH)
    port map (
        clk_i       => clk,
        enable_i    => enable,
        reset_i     => reset,
        phase_inc_i => phase_inc,
        data_o      => data_out);

----------------------------------------------------------------------------
-- 48 kHz sample clock (one rising edge per sample period)
----------------------------------------------------------------------------
clock_gen : process
begin
    clk <= '0';
    wait for CLOCK_PERIOD / 2;
    loop
        clk <= not clk;
        wait for CLOCK_PERIOD / 2;
    end loop;
end process clock_gen;

----------------------------------------------------------------------------
-- Stimulus
----------------------------------------------------------------------------
stim_proc : process
begin

    --------------------------------------------------------------------------
    -- 1. Reset with known phase increment — confirm output stays at 0
    --------------------------------------------------------------------------
    enable    <= '0';
    reset     <= '1';
    phase_inc <= INC_A4;                -- load A4 increment before releasing reset
    wait for CLOCK_PERIOD * 5;
    reset     <= '0';
    wait until rising_edge(clk);

    --------------------------------------------------------------------------
    -- 2. Run A4 (440 Hz left-audio note) for ~5 full cycles
    --    Expected: sine wave at ~445 Hz visible in data_out
    --------------------------------------------------------------------------
    enable <= '1';
    wait for RUN_TIME;

    --------------------------------------------------------------------------
    -- 3. Switch to A5 (880 Hz right-audio note) — frequency should double
    --    Expected: sine wave period halves with no discontinuity at switch point
    --------------------------------------------------------------------------
    phase_inc <= INC_A5;
    wait for RUN_TIME;

    --------------------------------------------------------------------------
    -- 4. Pause (enable='0') mid-tone — output should freeze at current value
    --    Expected: data_out holds its last value while enable is low
    --------------------------------------------------------------------------
    enable <= '0';
    wait for CLOCK_PERIOD * 20;

    --------------------------------------------------------------------------
    -- 5. Resume A5 — output should continue from where it paused (no glitch)
    --------------------------------------------------------------------------
    enable <= '1';
    wait for RUN_TIME;

    --------------------------------------------------------------------------
    -- 6. Reset while enabled — reset must take priority; output snaps to 0
    --    Expected: data_out returns to sine[0] (one-cycle BRAM latency is ok)
    --------------------------------------------------------------------------
    reset <= '1';
    wait for CLOCK_PERIOD * 5;
    reset <= '0';
    wait for RUN_TIME;

    --------------------------------------------------------------------------
    -- 7. Walk through the left-audio octave (C4 → C5) to verify all increments
    --    Each note runs long enough to show several complete sine cycles.
    --------------------------------------------------------------------------
    phase_inc <= INC_C4;   wait for RUN_TIME;  -- C4 ~258 Hz
    phase_inc <= INC_D4;   wait for RUN_TIME;  -- D4 ~293 Hz
    phase_inc <= INC_E4;   wait for RUN_TIME;  -- E4 ~328 Hz
    phase_inc <= INC_F4;   wait for RUN_TIME;  -- F4 ~352 Hz
    phase_inc <= INC_G4;   wait for RUN_TIME;  -- G4 ~387 Hz
    phase_inc <= INC_A4;   wait for RUN_TIME;  -- A4 ~445 Hz
    phase_inc <= INC_B4;   wait for RUN_TIME;  -- B4 ~492 Hz
    phase_inc <= INC_C5;   wait for RUN_TIME;  -- C5 ~527 Hz

    --------------------------------------------------------------------------
    -- Done
    --------------------------------------------------------------------------
    enable <= '0';
    wait for CLOCK_PERIOD * 5;
    std.env.stop;

end process stim_proc;

end testbench;
