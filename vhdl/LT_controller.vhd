LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

ENTITY dfsm IS
    PORT (
        fsm_clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
		-- Indicators from other blocks to trigger states
        tx_ready : IN STD_LOGIC; -- indication from EC to start reading TX_RAM and transmit
		rx_received : IN STD_LOGIC; -- indication from the RX line that a light message is incoming
		host_align : IN STD_LOGIC;
		device_align : IN STD_LOGIC;
		-- Add error signals that suggest to go to idle state?
		rx_error : OUT STD_LOGIC;
		tx_error : OUT STD_LOGIC;
		host : IN STD_LOGIC;

    );
END ENTITY dfsm;

ARCHITECTURE rtl OF dfsm IS

    TYPE fsm_states IS (RT, ID, TX, RX, RE, TE, HF, HA, DA); -- reset, idle, transmitting, receiving, receive error, transmit error, hard fault, host align, device align
    SIGNAL ps, ns : fsm_states := ID;

    SIGNAL rate : INTEGER := 50000000;
    SIGNAL clk : STD_LOGIC;
	SIGNAL RE_count : INTEGER := 0;
	SIGNAL TE_count : INTEGER := 0;
	-- count number of error signals


BEGIN

    sync_proc : PROCESS (clk, rst)
    BEGIN
        IF rst = '1' THEN
            ps <= RT;
        ELSIF rising_edge(clk) THEN
            ps <= ns;
        END IF;
    END PROCESS sync_proc;

    comb_proc : PROCESS (ps)
    BEGIN
        CASE ps IS

            WHEN RT =>
				-- Reset all light variables

				-- Go to idle state
				ns <= ID
                
            WHEN ID =>
				-- idle timer if in run state? usb should be running frequently enough that the system should not be in idle long? => tx_error/ hard fault
                IF (tx_ready = '1') THEN
                    ns <= TX;
					-- transition variable changes
				elsif (rx_received = '1') then
					ns <= RX;
					-- transition variable changes
                ELSE
                    ns <= ID;
                END IF;
            WHEN TX =>

                IF (tx_done = '1') THEN
                    ns <= ID;
					-- transition variable changes
                ELSE
                    ns <= TX;
                END IF;
			WHEN RX =>
				if (rx_error = '1') then
					ns <= RE;
					RE_count <= RE_count + 1;
					-- turn off rx_error somehow
				elsif (tx_error = '1') then
					ns <= TE;
					TE_count <= TE_count + 1;
                ELSIF (rx_done = '1') THEN
                    ns <= ID;
					RE_count <= 0;
					TE_count <= 0;
					-- transition variable changes

                ELSE
                    ns <= RX;
                END IF;	
		    WHEN RE =>
                IF (RE_count <3) THEN
					-- transition variable changes
					-- make message the TX_error message
					-- setup for transmit
					-- turn off rx_error signal

                    ns <= TX;
                ELSE
                    ns <= HF;
                END IF;
            WHEN TE =>

                IF (TE_count < 3) THEN
					-- transition variable changes
					-- enable TX for a retransmit
					-- indicate to other controllers TX retransmit in action
					-- Turn tx_error off

                    ns <= TX;
                ELSE

                    ns <= HF;
                END IF;
		     WHEN HF =>
					-- tell higher level controller in hard fault then send to align state?
                IF (host = '1') THEN
                    ns <= HA;
                ELSE
                    ns <= DA;
                END IF;
			WHEN HA =>
                IF (aligned = '1') THEN
                    ns <= ID;
                ELSE
                    ns <= HA;
                END IF;

			WHEN DA =>
                IF (aligned = '1') THEN
                    ns <= ID;
                ELSE
                    ns <= DA;
                END IF;

            WHEN OTHERS =>
                ns <= reset;


        END CASE;
    END PROCESS comb_proc;

END ARCHITECTURE rtl;