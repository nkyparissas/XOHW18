----------------------------------------------------------------------------------
-- TECHNICAL UNIVERSITY OF CRETE
-- NICK KYPARISSAS
--
-- CREATE DATE: JUNE 2018
-- MODULE: GRAPHICS FEEDER 
-- PROJECT NAME: A Parallel Framework for Simulating Cellular Automata on FPGA Logic
-- XILINX OPEN HARDWARE 2018 ENTRY
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY GRAPHICS_FEEDER IS
	GENERIC ( 	
				MEMORY_ADDRESS_WIDTH	: INTEGER := 27;
				GRID_Y				: INTEGER := 1080; -- NUMBER OF LINES
				NUMBER_OF_BURSTS_PER_LINE 	: INTEGER := 60
	);
    PORT ( 	CLK					: IN STD_LOGIC;	-- UI_CLK FROM MIG DDR CONTROLLER
			RST 				: IN STD_LOGIC;
			-- CONTROL SIGNALS --
			MEM_ACCESS_GRANTED	: IN STD_LOGIC;
			SPEED : IN INTEGER RANGE 0 TO 60; -- GRAPHICS RUN AT 60 FPS. SPEED = 30: NEW GENERATION EVERY 0.5 SEC. SPEED = 0: FULL SPEED, NEW GENERATION EVERY NEW FRAME.
			-- MEMORY SIGNALS --
			APP_RDY         	: IN STD_LOGIC;
			APP_ADDR 			: OUT STD_LOGIC_VECTOR(MEMORY_ADDRESS_WIDTH-1 DOWNTO 0);
			APP_EN	        	: OUT STD_LOGIC;
			APP_CMD 			: OUT STD_LOGIC_VECTOR(2 DOWNTO 0) -- "001" READ COMMAND
	);
END GRAPHICS_FEEDER;

ARCHITECTURE BEHAVIORAL OF GRAPHICS_FEEDER IS
    
    SIGNAL APP_ADDR_SIGNAL: UNSIGNED(19 DOWNTO 0) := (OTHERS => '0');
	SIGNAL BURSTS_REQUESTED_SUCCESSFULLY: UNSIGNED(6 DOWNTO 0) := (OTHERS => '0'); -- MUST BE LARGE ENOUGH TO COUNT NUMBER OF BURSTS PER FRAME LINE
    SIGNAL WAIT_FOR_APP_RDY, APP_EN_SIGNAL, SELECTED_FRAME : STD_LOGIC := '0';
	SIGNAL SPEED_COUNTER : INTEGER RANGE 0 TO 60 := 0;
	
    TYPE STATE IS (RESET, WAIT_FOR_NEXT_FRAME_LINE, LOAD_NEXT_FRAME_LINE, WAIT_FOR_CURRENT_LINE_TO_END);
            SIGNAL FSM_STATE : STATE;

BEGIN
    
	-- THE FOLLOWING FSM HANDLES THE DATA BEING RECEIVED  
	DATA_IN_FLOW_CONTROL: PROCESS 
	BEGIN
		
		WAIT UNTIL CLK'EVENT AND CLK = '1';
		
		IF (RST = '1') THEN  
			FSM_STATE <= RESET;    
		ELSE
			CASE FSM_STATE IS 
				WHEN RESET => 
					-- CONTROL SIGNALS --
					BURSTS_REQUESTED_SUCCESSFULLY <= (OTHERS => '0');
					-- 
					SPEED_COUNTER <= 0;
					-- MEMORY SIGNALS --
					APP_ADDR_SIGNAL <= (OTHERS => '0');
					APP_EN_SIGNAL <= '0';
					APP_CMD <= "001"; -- READ COMMAND
					-- FSM --
					WAIT_FOR_APP_RDY <= '0';
					FSM_STATE <= WAIT_FOR_NEXT_FRAME_LINE;
					--
					SELECTED_FRAME <= '0';
				WHEN WAIT_FOR_NEXT_FRAME_LINE => 
                    BURSTS_REQUESTED_SUCCESSFULLY <= (OTHERS => '0');
                    IF (APP_RDY = '1' AND MEM_ACCESS_GRANTED = '1') THEN -- 480 = 60*8, NUMBER OF BUFFERS IN ONE FRAME LINE
                        APP_EN_SIGNAL <= '1';
                        FSM_STATE <= LOAD_NEXT_FRAME_LINE;
                    ELSE 
                        APP_EN_SIGNAL <= '0';
                    END IF;                        
				WHEN LOAD_NEXT_FRAME_LINE =>
					IF BURSTS_REQUESTED_SUCCESSFULLY = NUMBER_OF_BURSTS_PER_LINE-1 THEN -- WE ARE CURRENTLY SENDING COMMAND FOR BURST 60
						IF APP_RDY = '1' THEN 
							BURSTS_REQUESTED_SUCCESSFULLY <= BURSTS_REQUESTED_SUCCESSFULLY + 1;
						END IF;
						APP_EN_SIGNAL <= '0';
						FSM_STATE <= WAIT_FOR_CURRENT_LINE_TO_END;
					ELSE
						IF APP_RDY = '1' THEN -- THE PREVIOUS COMMAND HAS BEEN ACCEPTED
							IF (APP_ADDR_SIGNAL < ((GRID_Y-1)*NUMBER_OF_BURSTS_PER_LINE*8 + (NUMBER_OF_BURSTS_PER_LINE-1)*8)) THEN 
							    APP_ADDR_SIGNAL <= APP_ADDR_SIGNAL + 8;
							ELSE
								APP_ADDR_SIGNAL <= (OTHERS => '0');
							END IF;
							BURSTS_REQUESTED_SUCCESSFULLY <= BURSTS_REQUESTED_SUCCESSFULLY + 1;
						ELSE
							BURSTS_REQUESTED_SUCCESSFULLY <= BURSTS_REQUESTED_SUCCESSFULLY;
							APP_ADDR_SIGNAL <= APP_ADDR_SIGNAL;
						END IF;
					END IF;
				WHEN WAIT_FOR_CURRENT_LINE_TO_END =>
					-- IF THE PREVIOUS COMMAND HAS NOT BEEN ACCEPTED
					IF BURSTS_REQUESTED_SUCCESSFULLY /= NUMBER_OF_BURSTS_PER_LINE THEN
						IF APP_RDY = '1' THEN
							APP_EN_SIGNAL <= '1';
						END IF;						
						IF APP_RDY = '1' AND APP_EN_SIGNAL = '1' THEN
							APP_EN_SIGNAL <= '0';
							BURSTS_REQUESTED_SUCCESSFULLY <= BURSTS_REQUESTED_SUCCESSFULLY + 1;
						END IF;

					END IF;
					-- THE FOLLOWING WILL HAPPEN AFTER NUMEROUS CYCLES 
                    IF (MEM_ACCESS_GRANTED = '0') THEN
						IF (APP_ADDR_SIGNAL > 0 AND APP_ADDR_SIGNAL < ((GRID_Y-1)*NUMBER_OF_BURSTS_PER_LINE*8 + (NUMBER_OF_BURSTS_PER_LINE-1)*8)) THEN 
							APP_ADDR_SIGNAL <= APP_ADDR_SIGNAL + 8;
						ELSE
							APP_ADDR_SIGNAL <= (OTHERS => '0');
							IF SPEED_COUNTER >= SPEED THEN
								SPEED_COUNTER <= 0;
								SELECTED_FRAME <= NOT SELECTED_FRAME;
							ELSE
								SPEED_COUNTER <= SPEED_COUNTER + 1;
							END IF;
						END IF;
                        FSM_STATE <= WAIT_FOR_NEXT_FRAME_LINE;
                    END IF;
			END CASE;
		END IF;
	
	END PROCESS DATA_IN_FLOW_CONTROL;

	APP_ADDR(19 DOWNTO 0) <= STD_LOGIC_VECTOR(APP_ADDR_SIGNAL);
	APP_ADDR(20) <= SELECTED_FRAME;
	APP_ADDR(APP_ADDR'HIGH DOWNTO 21) <= (OTHERS => '0');
	
	APP_EN <= APP_EN_SIGNAL;

END BEHAVIORAL;