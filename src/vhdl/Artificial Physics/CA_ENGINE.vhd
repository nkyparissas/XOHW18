----------------------------------------------------------------------------------
-- TECHNICAL UNIVERSITY OF CRETE
-- NICK KYPARISSAS
--
-- CREATE DATE: JUNE 2018
-- MODULE: Ca Engine implementing the "ARTIFICIAL PHYSICS" rule
-- PROJECT NAME: A Parallel Framework for Simulating Cellular Automata on FPGA Logic
-- XILINX OPEN HARDWARE 2018 ENTRY
----------------------------------------------------------------------------------
	
-- YOU CANT USE THIS AS IS: EVERY TIME THE NEIGHBORHOOD SIZE CHANGES, 
-- THE ADDERS BINARY TREE MIGHT REQUIRE CHANGES AS WELL. 

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY CA_ENGINE IS
	GENERIC (
        CELL_SIZE   	: INTEGER := 8; -- HOW MANY BITS PER CELL - WIDTH MUST BE DIVIDED BY CELL SIZE
        NEIGHBORHOOD_SIZE : INTEGER := 21);  -- OUTPUT DATA DEPTH IN CELLS - ARRAY DEPTH
        -- FOR EXAMPLE: IF WIDTH = 7 CELLS, CELL SIZE = 4 BITS AND DEPTH = 7 CELLS, THEN 
        -- DATA IN = 32 CELLS = 32*4 BITS = 128 BITS (IN MY APPLICATION: THIS WAS THE MEMORY BURST SIZE)
        -- DATA OUT = 7 CELLS = 7*4 BITS = 28 BITS
    PORT  ( 
    	CLK : IN STD_LOGIC;
    	RST : IN STD_LOGIC;
    	
    	READ_EN : IN STD_LOGIC;
    	DATA_IN : IN STD_LOGIC_VECTOR((NEIGHBORHOOD_SIZE*CELL_SIZE)-1 DOWNTO 0);
    	
    	DATA_OUT : OUT STD_LOGIC_VECTOR(CELL_SIZE-1 DOWNTO 0);
        DATA_OUT_VALID : OUT STD_LOGIC
    	
    );
END CA_ENGINE;

ARCHITECTURE BEHAVIORAL OF CA_ENGINE IS

-- PIPELINED NEIGHBORHOOD
type NEIGHBORHOOD_ARRAY is array (NEIGHBORHOOD_SIZE-1 downto 0, NEIGHBORHOOD_SIZE-1 downto 0) of integer range 0 to 2**CELL_SIZE;
SIGNAL NEIGHBORHOOD_CELL : NEIGHBORHOOD_ARRAY := (OTHERS => (OTHERS => 0));

-- NEIGHBORHOOD WEIGHTS
-- CURRENTLY ONLY UNSIGNED INTEGERS SUPPORTED
type NEIGHBORHOOD_WEIGHTS is array (NEIGHBORHOOD_SIZE-1 downto 0, NEIGHBORHOOD_SIZE-1 downto 0) of integer range 0 to 2**CELL_SIZE;
SIGNAL NEIGHBORHOOD_WEIGHT : NEIGHBORHOOD_WEIGHTS := (OTHERS => (OTHERS => 0));

-- EACH ARRAY CELL MUST BE LARGE ENOUGH FOR NEIGHBORHOOD_CELL*NEIGHBORHOOD_WEIGHT
type WEIGHTED_NEIGHBORHOOD_ARRAY is array (NEIGHBORHOOD_SIZE-1 downto 0, NEIGHBORHOOD_SIZE-1 downto 0) of integer range 0 to 2**(2*CELL_SIZE);
SIGNAL WEIGHTED_NEIGHBORHOOD_CELL : WEIGHTED_NEIGHBORHOOD_ARRAY := (OTHERS => (OTHERS => 0));

-- YOU NEED TO ADJUST THIS SIGNAL ACCORDING TO THE DEPTH OF YOUR RULE'S PIPELINE 
SIGNAL DATA_VALID_SIGNAL : STD_LOGIC_VECTOR( ((NEIGHBORHOOD_SIZE-1)/2)+12 DOWNTO 0) := (OTHERS => '0');

-- CUSTOM RULE SIGNALS
-- NORMALLY THERE WOULD BE AN OVERFLOW WITH THE FOLLOWING INTEGER RANGES, BUT WE KNOW THE MAXIMUM VALUES OF THE SUMS OF OUR RULE
type SUM_LAYER_0_TYPE is array ((NEIGHBORHOOD_SIZE-1)/2 downto 0, NEIGHBORHOOD_SIZE-1 downto 0) of integer range 0 to 1023;
SIGNAL SUM_LAYER_0 : SUM_LAYER_0_TYPE;
type SUM_LAYER_1_TYPE is array ((NEIGHBORHOOD_SIZE-1)/4 downto 0, NEIGHBORHOOD_SIZE-1 downto 0) of integer range 0 to 1023;
SIGNAL SUM_LAYER_1 : SUM_LAYER_1_TYPE;
type SUM_LAYER_2_TYPE is array (2 downto 0, NEIGHBORHOOD_SIZE-1 downto 0) of integer range 0 to 1023;
SIGNAL SUM_LAYER_2 : SUM_LAYER_2_TYPE;
type SUM_LAYER_3_TYPE is array (1 downto 0, NEIGHBORHOOD_SIZE-1 downto 0) of integer range 0 to 1023;
SIGNAL SUM_LAYER_3 : SUM_LAYER_3_TYPE;		
type SUM_TYPE is array (NEIGHBORHOOD_SIZE-1 downto 0) of integer range 0 to 1023;
SIGNAL SUM : SUM_TYPE;	
type COLUMN_SUM_LAYER_0_TYPE is array ((NEIGHBORHOOD_SIZE-1)/2 downto 0) of integer range 0 to 1023;
SIGNAL COLUMN_SUM_LAYER_0 : COLUMN_SUM_LAYER_0_TYPE;
type COLUMN_SUM_LAYER_1_TYPE is array ((NEIGHBORHOOD_SIZE-1)/4 downto 0) of integer range 0 to 1023;
SIGNAL COLUMN_SUM_LAYER_1 : COLUMN_SUM_LAYER_1_TYPE;
type COLUMN_SUM_LAYER_2_TYPE is array (2 downto 0) of integer range 0 to 1023;
SIGNAL COLUMN_SUM_LAYER_2 : COLUMN_SUM_LAYER_2_TYPE;
type COLUMN_SUM_LAYER_3_TYPE is array (1 downto 0) of integer range 0 to 1023;
SIGNAL COLUMN_SUM_LAYER_3 : COLUMN_SUM_LAYER_3_TYPE;		
SIGNAL TOTAL_SUM : integer range 0 to 1023;	
	
BEGIN
     
	PROCESS 
	BEGIN
		
		WAIT UNTIL RISING_EDGE(CLK);	
		
		IF RST = '1' THEN
			DATA_VALID_SIGNAL <= (OTHERS => '0');
		END IF;
		
		-- PIPELINING NEIGHBORHOOD ----------------------------------
        -- USE THIS AS IS FOR ANY WEIGHTED CA
        FOR I IN NEIGHBORHOOD_SIZE-1 DOWNTO 1 LOOP
            FOR J IN NEIGHBORHOOD_SIZE-1 DOWNTO 0 LOOP
                NEIGHBORHOOD_CELL(I, J) <= NEIGHBORHOOD_CELL(I-1, J);
            END LOOP;
        END LOOP;
        
          FOR I IN NEIGHBORHOOD_SIZE-1 DOWNTO 0 LOOP
            NEIGHBORHOOD_CELL(0, I) <= TO_INTEGER(UNSIGNED(DATA_IN((I*CELL_SIZE)+CELL_SIZE-1 DOWNTO I*CELL_SIZE)));
        END LOOP;
        -- APPLYING WEIGHTS
        FOR I IN NEIGHBORHOOD_SIZE-1 DOWNTO 0 LOOP
            FOR J IN NEIGHBORHOOD_SIZE-1 DOWNTO 0 LOOP
                WEIGHTED_NEIGHBORHOOD_CELL(I, J) <= NEIGHBORHOOD_CELL(I, J)*NEIGHBORHOOD_WEIGHT(I, J);
            END LOOP;
        END LOOP;
        ------------------------------------------------------------
		
		-- BINARY ADDER TREE ---------------------------------------
		-- YOU NEED TO CHANGE THIS FOR A DIFFERENT NEIGHBORHOOD SIZE
		FOR J IN NEIGHBORHOOD_SIZE-1 DOWNTO 0 LOOP
			-- LOOP FOR EACH COLUMN:
			FOR I IN (NEIGHBORHOOD_SIZE-1)/2 DOWNTO 1 LOOP -- 21 = 2*10 + 1, 10 SUM RESULTS
				SUM_LAYER_0(I, J) <= WEIGHTED_NEIGHBORHOOD_CELL(2*I, J) + WEIGHTED_NEIGHBORHOOD_CELL(2*I-1, J);
			END LOOP;
			
			SUM_LAYER_0(0, J) <= WEIGHTED_NEIGHBORHOOD_CELL(0, J); 
			
			FOR I IN (NEIGHBORHOOD_SIZE-1)/4 DOWNTO 1 LOOP -- 10 = 2*5, 5 SUM RESULTS
				SUM_LAYER_1(I, J) <= SUM_LAYER_0(2*I, J) + SUM_LAYER_0(2*I-1, J);
			END LOOP;
			
			SUM_LAYER_1(0, J) <= SUM_LAYER_0(0, J);
			
			SUM_LAYER_2(2, J) <= SUM_LAYER_1(5, J) + SUM_LAYER_1(4, J);
			SUM_LAYER_2(1, J) <= SUM_LAYER_1(3, J) + SUM_LAYER_1(2, J);
			SUM_LAYER_2(0, J) <= SUM_LAYER_1(1, J) + SUM_LAYER_1(0, J);
			
			SUM_LAYER_3(1, J) <= SUM_LAYER_2(2, J) + SUM_LAYER_2(1, J);
			SUM_LAYER_3(0, J) <= SUM_LAYER_2(0, J);
			
			SUM(J) <= SUM_LAYER_3(1, J) + SUM_LAYER_3(0, J);
		END LOOP;
		-- SUM(J) CONTAINS THE SUM OF COLUMN J
		-- ADDER TREE FOR THE SUM OF EACH COLUMN:
		FOR I IN (NEIGHBORHOOD_SIZE-1)/2 DOWNTO 1 LOOP -- 21 = 2*10 + 1, 10 SUM RESULTS
			COLUMN_SUM_LAYER_0(I) <= SUM(2*I) + SUM(2*I-1);
		END LOOP;
		
		COLUMN_SUM_LAYER_0(0) <= SUM(0); 
		
		FOR I IN (NEIGHBORHOOD_SIZE-1)/4 DOWNTO 1 LOOP -- 10 = 2*5, 5 SUM RESULTS
			COLUMN_SUM_LAYER_1(I) <= COLUMN_SUM_LAYER_0(2*I) + COLUMN_SUM_LAYER_0(2*I-1);
		END LOOP;
		
		COLUMN_SUM_LAYER_1(0) <= COLUMN_SUM_LAYER_0(0);
		
		COLUMN_SUM_LAYER_2(2) <= COLUMN_SUM_LAYER_1(5) + COLUMN_SUM_LAYER_1(4);
		COLUMN_SUM_LAYER_2(1) <= COLUMN_SUM_LAYER_1(3) + COLUMN_SUM_LAYER_1(2);
		COLUMN_SUM_LAYER_2(0) <= COLUMN_SUM_LAYER_1(1) + COLUMN_SUM_LAYER_1(0);
		
		COLUMN_SUM_LAYER_3(1) <= COLUMN_SUM_LAYER_2(2) + COLUMN_SUM_LAYER_2(1);
		COLUMN_SUM_LAYER_3(0) <= COLUMN_SUM_LAYER_2(0);
		
		TOTAL_SUM <= COLUMN_SUM_LAYER_3(1) + COLUMN_SUM_LAYER_3(0);
		------------------------------------------------------------
		
		-- STATE TRANSITION RULE -----------------------------------
		if (TOTAL_SUM <= 19) then
			DATA_OUT <= (OTHERS => '0');
		ELSIF (TOTAL_SUM <= 23) THEN 
			DATA_OUT <= "0001";
		elsif (TOTAL_SUM <= 58) THEN
			DATA_OUT <= (OTHERS => '0');
		elsif (TOTAL_SUM <= 100) THEN
			DATA_OUT <= "0001";
		else
			DATA_OUT <= (OTHERS => '0');
		END IF;
		------------------------------------------------------------
		
		FOR I IN ((NEIGHBORHOOD_SIZE-1)/2)+12 DOWNTO 1 LOOP
            DATA_VALID_SIGNAL(I) <= DATA_VALID_SIGNAL(I-1);
        END LOOP;
        DATA_VALID_SIGNAL(0) <= READ_EN;		
		
	END PROCESS;
		
	DATA_OUT_VALID <= DATA_VALID_SIGNAL(((NEIGHBORHOOD_SIZE-1)/2)+12);	
	
	-- SETTING WEIGHTS -----------------------------------------
		-- ROW 0
		NEIGHBORHOOD_WEIGHT(0, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 1) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 3) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 4) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 5) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 6) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 7) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 8) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 9) <= 1;
		NEIGHBORHOOD_WEIGHT(0, 10) <= 1;
		NEIGHBORHOOD_WEIGHT(0, 11) <= 1;
		NEIGHBORHOOD_WEIGHT(0, 12) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 13) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 14) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 15) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 16) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 17) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 19) <= 0;
		NEIGHBORHOOD_WEIGHT(0, 20) <= 0;
		-- ROW 1
		NEIGHBORHOOD_WEIGHT(1, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(1, 1) <= 0;
		NEIGHBORHOOD_WEIGHT(1, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(1, 3) <= 0;
		NEIGHBORHOOD_WEIGHT(1, 4) <= 0;
		NEIGHBORHOOD_WEIGHT(1, 5) <= 0;
		NEIGHBORHOOD_WEIGHT(1, 6) <= 1;
		NEIGHBORHOOD_WEIGHT(1, 7) <= 1;
		NEIGHBORHOOD_WEIGHT(1, 8) <= 1;
		NEIGHBORHOOD_WEIGHT(1, 9) <= 0;
		NEIGHBORHOOD_WEIGHT(1, 10) <= 0;
		NEIGHBORHOOD_WEIGHT(1, 11) <= 0;
		NEIGHBORHOOD_WEIGHT(1, 12) <= 1;
		NEIGHBORHOOD_WEIGHT(1, 13) <= 1;
		NEIGHBORHOOD_WEIGHT(1, 14) <= 1;
		NEIGHBORHOOD_WEIGHT(1, 15) <= 0;
		NEIGHBORHOOD_WEIGHT(1, 16) <= 0;
		NEIGHBORHOOD_WEIGHT(1, 17) <= 0;
		NEIGHBORHOOD_WEIGHT(1, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(1, 19) <= 0;
		NEIGHBORHOOD_WEIGHT(1, 20) <= 0;
		-- ROW 2
		NEIGHBORHOOD_WEIGHT(2, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 1) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 3) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 4) <= 1;
		NEIGHBORHOOD_WEIGHT(2, 5) <= 1;
		NEIGHBORHOOD_WEIGHT(2, 6) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 7) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 8) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 9) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 10) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 11) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 12) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 13) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 14) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 15) <= 1;
		NEIGHBORHOOD_WEIGHT(2, 16) <= 1;
		NEIGHBORHOOD_WEIGHT(2, 17) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 19) <= 0;
		NEIGHBORHOOD_WEIGHT(2, 20) <= 0;
		-- ROW 3
		NEIGHBORHOOD_WEIGHT(3, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(3, 1) <= 0;
		NEIGHBORHOOD_WEIGHT(3, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(3, 3) <= 1;
		NEIGHBORHOOD_WEIGHT(3, 4) <= 0;
		NEIGHBORHOOD_WEIGHT(3, 5) <= 0;
		NEIGHBORHOOD_WEIGHT(3, 6) <= 0;
		NEIGHBORHOOD_WEIGHT(3, 7) <= 0;
		NEIGHBORHOOD_WEIGHT(3, 8) <= 1;
		NEIGHBORHOOD_WEIGHT(3, 9) <= 1;
		NEIGHBORHOOD_WEIGHT(3, 10) <= 1;
		NEIGHBORHOOD_WEIGHT(3, 11) <= 1;
		NEIGHBORHOOD_WEIGHT(3, 12) <= 1;
		NEIGHBORHOOD_WEIGHT(3, 13) <= 0;
		NEIGHBORHOOD_WEIGHT(3, 14) <= 0;
		NEIGHBORHOOD_WEIGHT(3, 15) <= 0;
		NEIGHBORHOOD_WEIGHT(3, 16) <= 0;
		NEIGHBORHOOD_WEIGHT(3, 17) <= 1;
		NEIGHBORHOOD_WEIGHT(3, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(3, 19) <= 0;
		NEIGHBORHOOD_WEIGHT(3, 20) <= 0;
		-- ROW 4
		NEIGHBORHOOD_WEIGHT(4, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(4, 1) <= 0;
		NEIGHBORHOOD_WEIGHT(4, 2) <= 1;
		NEIGHBORHOOD_WEIGHT(4, 3) <= 0;
		NEIGHBORHOOD_WEIGHT(4, 4) <= 0;
		NEIGHBORHOOD_WEIGHT(4, 5) <= 0;
		NEIGHBORHOOD_WEIGHT(4, 6) <= 1;
		NEIGHBORHOOD_WEIGHT(4, 7) <= 1;
		NEIGHBORHOOD_WEIGHT(4, 8) <= 0;
		NEIGHBORHOOD_WEIGHT(4, 9) <= 0;
		NEIGHBORHOOD_WEIGHT(4, 10) <= 0;
		NEIGHBORHOOD_WEIGHT(4, 11) <= 0;
		NEIGHBORHOOD_WEIGHT(4, 12) <= 0;
		NEIGHBORHOOD_WEIGHT(4, 13) <= 1;
		NEIGHBORHOOD_WEIGHT(4, 14) <= 1;
		NEIGHBORHOOD_WEIGHT(4, 15) <= 0;
		NEIGHBORHOOD_WEIGHT(4, 16) <= 0;
		NEIGHBORHOOD_WEIGHT(4, 17) <= 0;
		NEIGHBORHOOD_WEIGHT(4, 18) <= 1;
		NEIGHBORHOOD_WEIGHT(4, 19) <= 0;
		NEIGHBORHOOD_WEIGHT(4, 20) <= 0;
		-- ROW 5
		NEIGHBORHOOD_WEIGHT(5, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(5, 1) <= 0;
		NEIGHBORHOOD_WEIGHT(5, 2) <= 1;
		NEIGHBORHOOD_WEIGHT(5, 3) <= 0;
		NEIGHBORHOOD_WEIGHT(5, 4) <= 0;
		NEIGHBORHOOD_WEIGHT(5, 5) <= 1;
		NEIGHBORHOOD_WEIGHT(5, 6) <= 0;
		NEIGHBORHOOD_WEIGHT(5, 7) <= 0;
		NEIGHBORHOOD_WEIGHT(5, 8) <= 0;
		NEIGHBORHOOD_WEIGHT(5, 9) <= 1;
		NEIGHBORHOOD_WEIGHT(5, 10) <= 1;
		NEIGHBORHOOD_WEIGHT(5, 11) <= 1;
		NEIGHBORHOOD_WEIGHT(5, 12) <= 0;
		NEIGHBORHOOD_WEIGHT(5, 13) <= 0;
		NEIGHBORHOOD_WEIGHT(5, 14) <= 0;
		NEIGHBORHOOD_WEIGHT(5, 15) <= 1;
		NEIGHBORHOOD_WEIGHT(5, 16) <= 0;
		NEIGHBORHOOD_WEIGHT(5, 17) <= 0;
		NEIGHBORHOOD_WEIGHT(5, 18) <= 1;
		NEIGHBORHOOD_WEIGHT(5, 19) <= 0;
		NEIGHBORHOOD_WEIGHT(5, 20) <= 0;
		-- ROW 6
		NEIGHBORHOOD_WEIGHT(6, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(6, 1) <= 1;
		NEIGHBORHOOD_WEIGHT(6, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(6, 3) <= 0;
		NEIGHBORHOOD_WEIGHT(6, 4) <= 1;
		NEIGHBORHOOD_WEIGHT(6, 5) <= 0;
		NEIGHBORHOOD_WEIGHT(6, 6) <= 0;
		NEIGHBORHOOD_WEIGHT(6, 7) <= 1;
		NEIGHBORHOOD_WEIGHT(6, 8) <= 1;
		NEIGHBORHOOD_WEIGHT(6, 9) <= 0;
		NEIGHBORHOOD_WEIGHT(6, 10) <= 0;
		NEIGHBORHOOD_WEIGHT(6, 11) <= 0;
		NEIGHBORHOOD_WEIGHT(6, 12) <= 1;
		NEIGHBORHOOD_WEIGHT(6, 13) <= 1;
		NEIGHBORHOOD_WEIGHT(6, 14) <= 0;
		NEIGHBORHOOD_WEIGHT(6, 15) <= 0;
		NEIGHBORHOOD_WEIGHT(6, 16) <= 1;
		NEIGHBORHOOD_WEIGHT(6, 17) <= 0;
		NEIGHBORHOOD_WEIGHT(6, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(6, 19) <= 1;
		NEIGHBORHOOD_WEIGHT(6, 20) <= 0;
		-- ROW 7
		NEIGHBORHOOD_WEIGHT(7, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(7, 1) <= 1;
		NEIGHBORHOOD_WEIGHT(7, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(7, 3) <= 0;
		NEIGHBORHOOD_WEIGHT(7, 4) <= 1;
		NEIGHBORHOOD_WEIGHT(7, 5) <= 0;
		NEIGHBORHOOD_WEIGHT(7, 6) <= 1;
		NEIGHBORHOOD_WEIGHT(7, 7) <= 0;
		NEIGHBORHOOD_WEIGHT(7, 8) <= 0;
		NEIGHBORHOOD_WEIGHT(7, 9) <= 1;
		NEIGHBORHOOD_WEIGHT(7, 10) <= 1;
		NEIGHBORHOOD_WEIGHT(7, 11) <= 1;
		NEIGHBORHOOD_WEIGHT(7, 12) <= 0;
		NEIGHBORHOOD_WEIGHT(7, 13) <= 0;
		NEIGHBORHOOD_WEIGHT(7, 14) <= 1;
		NEIGHBORHOOD_WEIGHT(7, 15) <= 0;
		NEIGHBORHOOD_WEIGHT(7, 16) <= 1;
		NEIGHBORHOOD_WEIGHT(7, 17) <= 0;
		NEIGHBORHOOD_WEIGHT(7, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(7, 19) <= 1;
		NEIGHBORHOOD_WEIGHT(7, 20) <= 0;
		-- ROW 8
		NEIGHBORHOOD_WEIGHT(8, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(8, 1) <= 1;
		NEIGHBORHOOD_WEIGHT(8, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(8, 3) <= 1;
		NEIGHBORHOOD_WEIGHT(8, 4) <= 0;
		NEIGHBORHOOD_WEIGHT(8, 5) <= 0;
		NEIGHBORHOOD_WEIGHT(8, 6) <= 1;
		NEIGHBORHOOD_WEIGHT(8, 7) <= 0;
		NEIGHBORHOOD_WEIGHT(8, 8) <= 1;
		NEIGHBORHOOD_WEIGHT(8, 9) <= 0;
		NEIGHBORHOOD_WEIGHT(8, 10) <= 0;
		NEIGHBORHOOD_WEIGHT(8, 11) <= 0;
		NEIGHBORHOOD_WEIGHT(8, 12) <= 1;
		NEIGHBORHOOD_WEIGHT(8, 13) <= 0;
		NEIGHBORHOOD_WEIGHT(8, 14) <= 1;
		NEIGHBORHOOD_WEIGHT(8, 15) <= 0;
		NEIGHBORHOOD_WEIGHT(8, 16) <= 0;
		NEIGHBORHOOD_WEIGHT(8, 17) <= 1;
		NEIGHBORHOOD_WEIGHT(8, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(8, 19) <= 1;
		NEIGHBORHOOD_WEIGHT(8, 20) <= 0;
		-- ROW 9
		NEIGHBORHOOD_WEIGHT(9, 0) <= 1;
		NEIGHBORHOOD_WEIGHT(9, 1) <= 0;
		NEIGHBORHOOD_WEIGHT(9, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(9, 3) <= 1;
		NEIGHBORHOOD_WEIGHT(9, 4) <= 0;
		NEIGHBORHOOD_WEIGHT(9, 5) <= 1;
		NEIGHBORHOOD_WEIGHT(9, 6) <= 0;
		NEIGHBORHOOD_WEIGHT(9, 7) <= 1;
		NEIGHBORHOOD_WEIGHT(9, 8) <= 0;
		NEIGHBORHOOD_WEIGHT(9, 9) <= 1;
		NEIGHBORHOOD_WEIGHT(9, 10) <= 1;
		NEIGHBORHOOD_WEIGHT(9, 11) <= 1;
		NEIGHBORHOOD_WEIGHT(9, 12) <= 0;
		NEIGHBORHOOD_WEIGHT(9, 13) <= 1;
		NEIGHBORHOOD_WEIGHT(9, 14) <= 0;
		NEIGHBORHOOD_WEIGHT(9, 15) <= 1;
		NEIGHBORHOOD_WEIGHT(9, 16) <= 0;
		NEIGHBORHOOD_WEIGHT(9, 17) <= 1;
		NEIGHBORHOOD_WEIGHT(9, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(9, 19) <= 0;
		NEIGHBORHOOD_WEIGHT(9, 20) <= 1;
		-- ROW 10
		NEIGHBORHOOD_WEIGHT(10, 0) <= 1;
		NEIGHBORHOOD_WEIGHT(10, 1) <= 0;
		NEIGHBORHOOD_WEIGHT(10, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(10, 3) <= 1;
		NEIGHBORHOOD_WEIGHT(10, 4) <= 0;
		NEIGHBORHOOD_WEIGHT(10, 5) <= 1;
		NEIGHBORHOOD_WEIGHT(10, 6) <= 0;
		NEIGHBORHOOD_WEIGHT(10, 7) <= 1;
		NEIGHBORHOOD_WEIGHT(10, 8) <= 0;
		NEIGHBORHOOD_WEIGHT(10, 9) <= 1;
		NEIGHBORHOOD_WEIGHT(10, 10) <= 1; --0;
		NEIGHBORHOOD_WEIGHT(10, 11) <= 1;
		NEIGHBORHOOD_WEIGHT(10, 12) <= 0;
		NEIGHBORHOOD_WEIGHT(10, 13) <= 1;
		NEIGHBORHOOD_WEIGHT(10, 14) <= 0;
		NEIGHBORHOOD_WEIGHT(10, 15) <= 1;
		NEIGHBORHOOD_WEIGHT(10, 16) <= 0;
		NEIGHBORHOOD_WEIGHT(10, 17) <= 1;
		NEIGHBORHOOD_WEIGHT(10, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(10, 19) <= 0;
		NEIGHBORHOOD_WEIGHT(10, 20) <= 1;
	    -- ROW 20
		NEIGHBORHOOD_WEIGHT(20, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 1) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 3) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 4) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 5) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 6) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 7) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 8) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 9) <= 1;
		NEIGHBORHOOD_WEIGHT(20, 10) <= 1;
		NEIGHBORHOOD_WEIGHT(20, 11) <= 1;
		NEIGHBORHOOD_WEIGHT(20, 12) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 13) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 14) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 15) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 16) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 17) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 19) <= 0;
		NEIGHBORHOOD_WEIGHT(20, 20) <= 0;
		-- ROW 19
		NEIGHBORHOOD_WEIGHT(19, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(19, 1) <= 0;
		NEIGHBORHOOD_WEIGHT(19, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(19, 3) <= 0;
		NEIGHBORHOOD_WEIGHT(19, 4) <= 0;
		NEIGHBORHOOD_WEIGHT(19, 5) <= 0;
		NEIGHBORHOOD_WEIGHT(19, 6) <= 1;
		NEIGHBORHOOD_WEIGHT(19, 7) <= 1;
		NEIGHBORHOOD_WEIGHT(19, 8) <= 1;
		NEIGHBORHOOD_WEIGHT(19, 9) <= 0;
		NEIGHBORHOOD_WEIGHT(19, 10) <= 0;
		NEIGHBORHOOD_WEIGHT(19, 11) <= 0;
		NEIGHBORHOOD_WEIGHT(19, 12) <= 1;
		NEIGHBORHOOD_WEIGHT(19, 13) <= 1;
		NEIGHBORHOOD_WEIGHT(19, 14) <= 1;
		NEIGHBORHOOD_WEIGHT(19, 15) <= 0;
		NEIGHBORHOOD_WEIGHT(19, 16) <= 0;
		NEIGHBORHOOD_WEIGHT(19, 17) <= 0;
		NEIGHBORHOOD_WEIGHT(19, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(19, 19) <= 0;
		NEIGHBORHOOD_WEIGHT(19, 20) <= 0;
		-- ROW 18
		NEIGHBORHOOD_WEIGHT(18, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 1) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 3) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 4) <= 1;
		NEIGHBORHOOD_WEIGHT(18, 5) <= 1;
		NEIGHBORHOOD_WEIGHT(18, 6) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 7) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 8) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 9) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 10) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 11) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 12) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 13) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 14) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 15) <= 1;
		NEIGHBORHOOD_WEIGHT(18, 16) <= 1;
		NEIGHBORHOOD_WEIGHT(18, 17) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 19) <= 0;
		NEIGHBORHOOD_WEIGHT(18, 20) <= 0;
		-- ROW 17
		NEIGHBORHOOD_WEIGHT(17, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(17, 1) <= 0;
		NEIGHBORHOOD_WEIGHT(17, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(17, 3) <= 1;
		NEIGHBORHOOD_WEIGHT(17, 4) <= 0;
		NEIGHBORHOOD_WEIGHT(17, 5) <= 0;
		NEIGHBORHOOD_WEIGHT(17, 6) <= 0;
		NEIGHBORHOOD_WEIGHT(17, 7) <= 0;
		NEIGHBORHOOD_WEIGHT(17, 8) <= 1;
		NEIGHBORHOOD_WEIGHT(17, 9) <= 1;
		NEIGHBORHOOD_WEIGHT(17, 10) <= 1;
		NEIGHBORHOOD_WEIGHT(17, 11) <= 1;
		NEIGHBORHOOD_WEIGHT(17, 12) <= 1;
		NEIGHBORHOOD_WEIGHT(17, 13) <= 0;
		NEIGHBORHOOD_WEIGHT(17, 14) <= 0;
		NEIGHBORHOOD_WEIGHT(17, 15) <= 0;
		NEIGHBORHOOD_WEIGHT(17, 16) <= 0;
		NEIGHBORHOOD_WEIGHT(17, 17) <= 1;
		NEIGHBORHOOD_WEIGHT(17, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(17, 19) <= 0;
		NEIGHBORHOOD_WEIGHT(17, 20) <= 0;
		-- ROW 16
		NEIGHBORHOOD_WEIGHT(16, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(16, 1) <= 0;
		NEIGHBORHOOD_WEIGHT(16, 2) <= 1;
		NEIGHBORHOOD_WEIGHT(16, 3) <= 0;
		NEIGHBORHOOD_WEIGHT(16, 4) <= 0;
		NEIGHBORHOOD_WEIGHT(16, 5) <= 0;
		NEIGHBORHOOD_WEIGHT(16, 6) <= 1;
		NEIGHBORHOOD_WEIGHT(16, 7) <= 1;
		NEIGHBORHOOD_WEIGHT(16, 8) <= 0;
		NEIGHBORHOOD_WEIGHT(16, 9) <= 0;
		NEIGHBORHOOD_WEIGHT(16, 10) <= 0;
		NEIGHBORHOOD_WEIGHT(16, 11) <= 0;
		NEIGHBORHOOD_WEIGHT(16, 12) <= 0;
		NEIGHBORHOOD_WEIGHT(16, 13) <= 1;
		NEIGHBORHOOD_WEIGHT(16, 14) <= 1;
		NEIGHBORHOOD_WEIGHT(16, 15) <= 0;
		NEIGHBORHOOD_WEIGHT(16, 16) <= 0;
		NEIGHBORHOOD_WEIGHT(16, 17) <= 0;
		NEIGHBORHOOD_WEIGHT(16, 18) <= 1;
		NEIGHBORHOOD_WEIGHT(16, 19) <= 0;
		NEIGHBORHOOD_WEIGHT(16, 20) <= 0;
		-- ROW 15
		NEIGHBORHOOD_WEIGHT(15, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(15, 1) <= 0;
		NEIGHBORHOOD_WEIGHT(15, 2) <= 1;
		NEIGHBORHOOD_WEIGHT(15, 3) <= 0;
		NEIGHBORHOOD_WEIGHT(15, 4) <= 0;
		NEIGHBORHOOD_WEIGHT(15, 5) <= 1;
		NEIGHBORHOOD_WEIGHT(15, 6) <= 0;
		NEIGHBORHOOD_WEIGHT(15, 7) <= 0;
		NEIGHBORHOOD_WEIGHT(15, 8) <= 0;
		NEIGHBORHOOD_WEIGHT(15, 9) <= 1;
		NEIGHBORHOOD_WEIGHT(15, 10) <= 1;
		NEIGHBORHOOD_WEIGHT(15, 11) <= 1;
		NEIGHBORHOOD_WEIGHT(15, 12) <= 0;
		NEIGHBORHOOD_WEIGHT(15, 13) <= 0;
		NEIGHBORHOOD_WEIGHT(15, 14) <= 0;
		NEIGHBORHOOD_WEIGHT(15, 15) <= 1;
		NEIGHBORHOOD_WEIGHT(15, 16) <= 0;
		NEIGHBORHOOD_WEIGHT(15, 17) <= 0;
		NEIGHBORHOOD_WEIGHT(15, 18) <= 1;
		NEIGHBORHOOD_WEIGHT(15, 19) <= 0;
		NEIGHBORHOOD_WEIGHT(15, 20) <= 0;
		-- ROW 14
		NEIGHBORHOOD_WEIGHT(14, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(14, 1) <= 1;
		NEIGHBORHOOD_WEIGHT(14, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(14, 3) <= 0;
		NEIGHBORHOOD_WEIGHT(14, 4) <= 1;
		NEIGHBORHOOD_WEIGHT(14, 5) <= 0;
		NEIGHBORHOOD_WEIGHT(14, 6) <= 0;
		NEIGHBORHOOD_WEIGHT(14, 7) <= 1;
		NEIGHBORHOOD_WEIGHT(14, 8) <= 1;
		NEIGHBORHOOD_WEIGHT(14, 9) <= 0;
		NEIGHBORHOOD_WEIGHT(14, 10) <= 0;
		NEIGHBORHOOD_WEIGHT(14, 11) <= 0;
		NEIGHBORHOOD_WEIGHT(14, 12) <= 1;
		NEIGHBORHOOD_WEIGHT(14, 13) <= 1;
		NEIGHBORHOOD_WEIGHT(14, 14) <= 0;
		NEIGHBORHOOD_WEIGHT(14, 15) <= 0;
		NEIGHBORHOOD_WEIGHT(14, 16) <= 1;
		NEIGHBORHOOD_WEIGHT(14, 17) <= 0;
		NEIGHBORHOOD_WEIGHT(14, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(14, 19) <= 1;
		NEIGHBORHOOD_WEIGHT(14, 20) <= 0;
		-- ROW 13
		NEIGHBORHOOD_WEIGHT(13, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(13, 1) <= 1;
		NEIGHBORHOOD_WEIGHT(13, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(13, 3) <= 0;
		NEIGHBORHOOD_WEIGHT(13, 4) <= 1;
		NEIGHBORHOOD_WEIGHT(13, 5) <= 0;
		NEIGHBORHOOD_WEIGHT(13, 6) <= 1;
		NEIGHBORHOOD_WEIGHT(13, 7) <= 0;
		NEIGHBORHOOD_WEIGHT(13, 8) <= 0;
		NEIGHBORHOOD_WEIGHT(13, 9) <= 1;
		NEIGHBORHOOD_WEIGHT(13, 10) <= 1;
		NEIGHBORHOOD_WEIGHT(13, 11) <= 1;
		NEIGHBORHOOD_WEIGHT(13, 12) <= 0;
		NEIGHBORHOOD_WEIGHT(13, 13) <= 0;
		NEIGHBORHOOD_WEIGHT(13, 14) <= 1;
		NEIGHBORHOOD_WEIGHT(13, 15) <= 0;
		NEIGHBORHOOD_WEIGHT(13, 16) <= 1;
		NEIGHBORHOOD_WEIGHT(13, 17) <= 0;
		NEIGHBORHOOD_WEIGHT(13, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(13, 19) <= 1;
		NEIGHBORHOOD_WEIGHT(13, 20) <= 0;
		-- ROW 12
		NEIGHBORHOOD_WEIGHT(12, 0) <= 0;
		NEIGHBORHOOD_WEIGHT(12, 1) <= 1;
		NEIGHBORHOOD_WEIGHT(12, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(12, 3) <= 1;
		NEIGHBORHOOD_WEIGHT(12, 4) <= 0;
		NEIGHBORHOOD_WEIGHT(12, 5) <= 0;
		NEIGHBORHOOD_WEIGHT(12, 6) <= 1;
		NEIGHBORHOOD_WEIGHT(12, 7) <= 0;
		NEIGHBORHOOD_WEIGHT(12, 8) <= 1;
		NEIGHBORHOOD_WEIGHT(12, 9) <= 0;
		NEIGHBORHOOD_WEIGHT(12, 10) <= 0;
		NEIGHBORHOOD_WEIGHT(12, 11) <= 0;
		NEIGHBORHOOD_WEIGHT(12, 12) <= 1;
		NEIGHBORHOOD_WEIGHT(12, 13) <= 0;
		NEIGHBORHOOD_WEIGHT(12, 14) <= 1;
		NEIGHBORHOOD_WEIGHT(12, 15) <= 0;
		NEIGHBORHOOD_WEIGHT(12, 16) <= 0;
		NEIGHBORHOOD_WEIGHT(12, 17) <= 1;
		NEIGHBORHOOD_WEIGHT(12, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(12, 19) <= 1;
		NEIGHBORHOOD_WEIGHT(12, 20) <= 0;
		-- ROW 11
		NEIGHBORHOOD_WEIGHT(11, 0) <= 1;
		NEIGHBORHOOD_WEIGHT(11, 1) <= 0;
		NEIGHBORHOOD_WEIGHT(11, 2) <= 0;
		NEIGHBORHOOD_WEIGHT(11, 3) <= 1;
		NEIGHBORHOOD_WEIGHT(11, 4) <= 0;
		NEIGHBORHOOD_WEIGHT(11, 5) <= 1;
		NEIGHBORHOOD_WEIGHT(11, 6) <= 0;
		NEIGHBORHOOD_WEIGHT(11, 7) <= 1;
		NEIGHBORHOOD_WEIGHT(11, 8) <= 0;
		NEIGHBORHOOD_WEIGHT(11, 9) <= 1;
		NEIGHBORHOOD_WEIGHT(11, 10) <= 1;
		NEIGHBORHOOD_WEIGHT(11, 11) <= 1;
		NEIGHBORHOOD_WEIGHT(11, 12) <= 0;
		NEIGHBORHOOD_WEIGHT(11, 13) <= 1;
		NEIGHBORHOOD_WEIGHT(11, 14) <= 0;
		NEIGHBORHOOD_WEIGHT(11, 15) <= 1;
		NEIGHBORHOOD_WEIGHT(11, 16) <= 0;
		NEIGHBORHOOD_WEIGHT(11, 17) <= 1;
		NEIGHBORHOOD_WEIGHT(11, 18) <= 0;
		NEIGHBORHOOD_WEIGHT(11, 19) <= 0;
		NEIGHBORHOOD_WEIGHT(11, 20) <= 1;
		------------------------------------------------------------
	
END BEHAVIORAL;
	