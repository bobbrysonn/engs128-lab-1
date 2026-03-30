----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
----------------------------------------------------------------------------
--  ENGS 128
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: Top-level file for audio codec tone generator and data passthrough 
--  Target device: Zybo
--
--  SSM2603 audio codec datasheet: 
--      https://www.analog.com/media/en/technical-documentation/data-sheets/ssm2603.pdf
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;
----------------------------------------------------------------------------
-- Entity definition
entity top_level is
    Port (
		sysclk_i : in  std_logic;	
		
		-- User controls
		dds_reset_i : in STD_LOGIC;
		dds_enable_i  : in STD_LOGIC;
		dds_freq_sel_i : in STD_LOGIC_VECTOR(2 downto 0);
		ac_mute_en_i : in STD_LOGIC;
		
		-- Audio Codec I2S controls
        ac_bclk_o : out STD_LOGIC;
        ac_mclk_o : out STD_LOGIC;
        ac_mute_n_o : out STD_LOGIC;	-- Active Low
        
        -- Audio Codec DAC (audio out)
        ac_dac_data_o : out STD_LOGIC;
        ac_dac_lrclk_o : out STD_LOGIC;
        
        -- Audio Codec ADC (audio in)
        ac_adc_data_i : in STD_LOGIC;
        ac_adc_lrclk_o : out STD_LOGIC);
        
end top_level;
----------------------------------------------------------------------------
architecture Behavioral of top_level is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
constant AC_DATA_WIDTH : integer := 24;	-- audio data width

----------------------------------------------------------------------------
-- ++++ Add other signals and constants here ++++

----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------
-- ++++ Update/modify the component declarations to match your entities ++++
-- Clock generation
component i2s_clock_gen is
    Port (

        -- System clock in
		sysclk_125MHz_i   : in  std_logic;	
		
		-- Forwarded clocks
		mclk_fwd_o		  : out std_logic;	
		bclk_fwd_o        : out std_logic;
		adc_lrclk_fwd_o   : out std_logic;
		dac_lrclk_fwd_o   : out std_logic;

        -- Clocks for I2S components
		mclk_o		      : out std_logic;	
		bclk_o            : out std_logic;
		lrclk_o           : out std_logic);  
end component;

----------------------------------------------------------------------------------
-- I2S receiver
component i2s_receiver is
    Generic (AC_DATA_WIDTH : integer := AC_DATA_WIDTH);
    Port (

        -- Timing
		bclk_i    : in std_logic;	
		lrclk_i   : in std_logic;
		
		-- Data
		left_audio_data_o     : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_o    : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		adc_serial_data_i     : in std_logic);  
end component; 

----------------------------------------------------------------------------------
-- I2S transmitter
component i2s_transmitter is
    Generic (AC_DATA_WIDTH : integer := AC_DATA_WIDTH);
    Port (

        -- Timing
		bclk_i    : in std_logic;	
		lrclk_i   : in std_logic;
		
		-- Data
		left_audio_data_i     : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_i    : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		dac_serial_data_o     : out std_logic);  
end component; 

----------------------------------------------------------------------------------
-- DDS audio tone generator
component dds_controller is
-- ++++ Add your component declaration ++++
end component;

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Component instantiations
---------------------------------------------------------------------------- 
-- ++++ Add your port maps below ++++
-- Clock generation

---------------------------------------------------------------------------- 
-- I2S receiver

	
---------------------------------------------------------------------------- 
-- I2S transmitter


---------------------------------------------------------------------------- 
-- DDS Tone Generators
----------------------------------------------------------------------------     
-- DDS audio tone generator -- left audio


----------------------------------------------------------------------------     
-- DDS audio tone generator -- right audio


---------------------------------------------------------------------------- 
-- Logic
---------------------------------------------------------------------------- 
-- ++++ Add additional logic here ++++
-- ++++ This includes the DDS phase increment mux logic to generate the correct tones ++++


---------------------------------------------------------------------------- 
end Behavioral;