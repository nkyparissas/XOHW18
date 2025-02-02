----------------------------------------------------------------------------------
-- TECHNICAL UNIVERSITY OF CRETE
-- NICK KYPARISSAS
--
-- CREATE DATE: JUNE 2018
-- MODULE: FHD_CTRL - BEHAVIORAL
-- PROJECT NAME: A Parallel Framework for Simulating Cellular Automata on FPGA Logic
-- XILINX OPEN HARDWARE 2018 ENTRY
--
-- DESCRIPTION: THIS MODULE GENERATES THE VIDEO SYNCH PULSES FOR THE MONITOR TO
-- ENTER THE 1920x1080@60HZ RESOLUTION STATE, ACCORDING TO VESA's DMT STANDARD. 
-- IT ALSO PROVIDES HORIZONTAL
-- AND VERTICAL COUNTERS FOR THE CURRENTLY DISPLAYED PIXEL AND A BLANK
-- SIGNAL THAT IS ACTIVE WHEN THE PIXEL IS NOT INSIDE THE VISIBLE SCREEN
-- AND THE COLOR OUTPUTS SHOULD BE RESET TO 0.
--
-- BASED ON ULRICH ZOLTAN'S VGA CONTROLLER, COPYRIGHT 2006 DIGILENT, INC.
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
-- USE IEEE.STD_LOGIC_ARITH.ALL;
-- USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- SIMULATION LIBRARY
-- LIBRARY UNISIM;
-- USE UNISIM.VCOMPONENTS.ALL;

ENTITY FHD_CTRL IS
    PORT(
        RST         : IN STD_LOGIC;
        CLK         : IN STD_LOGIC; -- MUST BE @ 148.5 MHZ
        HS          : OUT STD_LOGIC;
        VS          : OUT STD_LOGIC;
        HCOUNT      : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
        VCOUNT      : OUT STD_LOGIC_VECTOR(10 DOWNTO 0)
	);
END FHD_CTRL;

ARCHITECTURE BEHAVIORAL OF FHD_CTRL IS
	
	------------------------------------------------------------------------
		-- CONSTANTS
	------------------------------------------------------------------------
    
    -- MAXIMUM VALUE FOR THE HORIZONTAL PIXEL COUNTER
    CONSTANT HMAX  : INTEGER := 2200; -- 2200 TOTAL PIXELS PER LINE
    -- MAXIMUM VALUE FOR THE VERTICAL PIXEL COUNTER
    CONSTANT VMAX  : INTEGER := 1125; -- 1125 TOTAL LINES
    -- TOTAL NUMBER OF VISIBLE COLUMNS
    -- CONSTANT HLINES: STD_LOGIC_VECTOR(10 DOWNTO 0) := "11110000000"; -- 1920 RESOLUTION WIDTH
    -- VALUE FOR THE HORIZONTAL COUNTER WHERE FRONT PORCH ENDS
    CONSTANT HFP   : INTEGER := 2008; -- 2008 = FRONT PORCH 88 PIXELS + 1920 
    -- VALUE FOR THE HORIZONTAL COUNTER WHERE THE SYNCH PULSE ENDS
    CONSTANT HSP   : INTEGER := 2052;  -- 2052 = HORIZONTAL SYNC 44 PIXELS + 2008
    -- TOTAL NUMBER OF VISIBLE LINES
    -- CONSTANT VLINES: STD_LOGIC_VECTOR(10 DOWNTO 0) := "10000111000"; -- 1080 RESOLUTION HEIGHT
    -- VALUE FOR THE VERTICAL COUNTER WHERE THE FRONT PORCH ENDS
    CONSTANT VFP   : INTEGER := 1084; -- 1084 = FRONT PORCH 4 LINES + 1080
    -- VALUE FOR THE VERTICAL COUNTER WHERE THE SYNCH PULSE ENDS
    CONSTANT VSP   : INTEGER := 1089; -- 1089 = VERTICAL SYNC 5 LINES + 1084
    -- POLARITY OF THE HORIZONTAL AND VERTICAL SYNCH PULSE
    CONSTANT HSP_P   : STD_LOGIC := '1';
    CONSTANT VSP_P   : STD_LOGIC := '1';
    
	------------------------------------------------------------------------
		-- SIGNALS
	------------------------------------------------------------------------
    
    -- HORIZONTAL AND VERTICAL COUNTERS
    SIGNAL HCOUNTER : INTEGER RANGE 0 TO HMAX := 0;
    SIGNAL VCOUNTER : INTEGER RANGE 0 TO VMAX := 0;
	
	------------------------------------------------------------------------

BEGIN
	
    -- OUTPUT HORIZONTAL AND VERTICAL COUNTERS.
    HCOUNT <= STD_LOGIC_VECTOR(TO_UNSIGNED(HCOUNTER, HCOUNT'LENGTH));
    VCOUNT <= STD_LOGIC_VECTOR(TO_UNSIGNED(VCOUNTER, VCOUNT'LENGTH));
	
    -- INCREMENT HORIZONTAL COUNTER AT CLK RATE
	-- UNTIL HMAX IS REACHED, THEN RESET AND KEEP COUNTING.
    H_COUNT: PROCESS
		BEGIN
        WAIT UNTIL CLK'EVENT AND CLK = '1' ;
		
		IF(RST = '1') THEN
			HCOUNTER <= 0;
		ELSIF(HCOUNTER = HMAX) THEN
			HCOUNTER <= 0;
		ELSE
			HCOUNTER <= HCOUNTER + 1;
		END IF;
	END PROCESS H_COUNT;
	
    -- INCREMENT VERTICAL COUNTER WHEN ONE LINE IS FINISHED
	-- (HORIZONTAL COUNTER REACHED HMAX)
	-- UNTIL VMAX IS REACHED, THEN RESET AND KEEP COUNTING.
    V_COUNT: PROCESS
		BEGIN
		WAIT UNTIL CLK'EVENT AND CLK= '1';
		
		IF(RST = '1') THEN
			VCOUNTER <= 0;
		ELSIF(HCOUNTER = HMAX) THEN
			IF(VCOUNTER = VMAX) THEN
				VCOUNTER <= 0;
			ELSE
				VCOUNTER <= VCOUNTER + 1;
			END IF;
		END IF;
	END PROCESS V_COUNT;
	
    -- GENERATE HORIZONTAL SYNCH PULSE
	-- WHEN HORIZONTAL COUNTER IS BETWEEN WHERE THE
	-- FRONT PORCH ENDS AND THE SYNCH PULSE ENDS.
	-- THE HS IS ACTIVE (WITH POLARITY HSP_P) FOR A TOTAL OF 44 PIXELS.
    DO_HS: PROCESS
		BEGIN
        WAIT UNTIL CLK'EVENT AND CLK='1';
		
		IF(HCOUNTER >= HFP AND HCOUNTER < HSP) THEN
			HS <= HSP_P;
		ELSE
			HS <= NOT HSP_P;
		END IF; 
	END PROCESS DO_HS;
	
    -- GENERATE VERTICAL SYNCH PULSE
	-- WHEN VERTICAL COUNTER IS BETWEEN WHERE THE
	-- FRONT PORCH ENDS AND THE SYNCH PULSE ENDS.
	-- THE VS IS ACTIVE (WITH POLARITY VSP_P) FOR A TOTAL OF 5 LINES.
    DO_VS: PROCESS
		BEGIN
        WAIT UNTIL CLK'EVENT AND CLK='1';
		
		IF(VCOUNTER >= VFP AND VCOUNTER < VSP) THEN
			VS <= VSP_P;
		ELSE
			VS <= NOT VSP_P;
		END IF;
	END PROCESS DO_VS;

END BEHAVIORAL;