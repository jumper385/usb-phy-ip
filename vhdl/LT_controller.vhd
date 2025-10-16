LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

ENTITY LT_controller IS
    PORT (
        fsm_clk : IN STD_LOGIC; 
        rst : IN STD_LOGIC;
		-- Indicators from other blocks to trigger states
        tx_ready : IN STD_LOGIC; -- indication from EC to start reading TX_RAM and transmit
		rx_received : IN STD_LOGIC; -- indication from the RX line that a light message is incoming
		rx_error : in STD_LOGIC;
        re_timeout : IN STD_LOGIC;
		tx_error : in STD_LOGIC;
        ena_t : out std_logic;
        ena_r : out std_logic;
        ena_re : out std_logic;
	    ena_man : out std_logic;
        message_sent : in std_logic;
        rx_done : in std_logic

    );
END ENTITY LT_controller;

ARCHITECTURE rtl OF LT_controller IS

    TYPE fsm_states IS (RT, ID, TX, RX, RE, RE2, TE1, TE2, HF); --, HF, HA, DA); -- reset, idle, transmitting, receiving, receive error, transmit error, hard fault, host align, device align
    SIGNAL ps, ns : fsm_states := ID;
    SIGNAL ena_t_s : STD_LOGIC := '0';
    SIGNAL ena_r_s : STD_LOGIC := '0';
    SIGNAL ena_RE_s : std_logic := '0';
    SIGNAL ena_man_s : std_logic := '0';
	-- SIGNAL RE_count : INTEGER := 0;
	-- SIGNAL TE_count : INTEGER := 0;
	-- count number of error signals


BEGIN
    ena_t <= ena_t_s;
    ena_r <= ena_r_s;
    ena_re <= ena_RE_s;
    ena_man<= ena_man_s;

    sync_proc : PROCESS (fsm_clk, rst)
    BEGIN
        IF rst = '0' THEN
            ps <= RT;
            -- RE_count <= 0;
            -- TE_count <= 0;
        ELSIF rising_edge(fsm_clk) THEN
            ps <= ns;
        END IF;
    END PROCESS sync_proc;

    comb_proc : PROCESS (ps, tx_ready, message_sent, rx_received, rx_done, tx_error, rx_error, re_timeout)
    BEGIN
	ena_t_s <= '0';
    ena_r_s <= '0';
	ena_RE_s <= '0';
	ena_man_s<= '0';
        CASE ps IS

            WHEN RT =>
				-- Reset all light variables
				-- Go to idle state
		ns <= ID;
                
            WHEN ID =>
				-- idle timer if in run state? usb should be running frequently enough that the system should not be in idle long? => tx_error/ hard fault
                IF (tx_ready = '1') THEN
                    ns <= TX;
		            ena_t_s <= '1';
				    ena_man_s <= '1';
			        ena_r_s <='1';
					-- transition variable changes
		        elsif (rx_received = '1') then
			        ns <= RX;
                    ena_r_s <= '1';
				-- 	-- transition variable changes
                ELSE
                    ns <= ID;
                END IF;
            WHEN TX =>
		        IF (tx_error = '1') then
                   ns <= TE1;
                elsif (message_sent = '1') then
                    ns <= ID;
                    ena_t_s <= '0';
			        ena_man_s <= '0';
                else
                    ns <= TX;
                    ena_t_s <= '1';
			        ena_man_s <= '1';
			        ena_r_s <= '1';
                END IF;


			WHEN RX =>
				if (rx_error = '1') then
					ns <= RE;
					ena_RE_s <= '1';
					ena_man_s <= '1';
					-- turn off rx_error somehow
				elsif (tx_error = '1') then
					ns <= TE1;
                ELSIF (rx_done = '1') THEN
                    ns <= ID;
                ELSE
                    ns <= RX;
                    ena_r_s <= '1';
                END IF;	
		    WHEN RE =>
                ns <= RE2;
            WHEN RE2 =>
                IF (re_timeout = '1') then
                    ns <= HF;
                ELSIF (rx_done = '1') then
                    ns <= ID;
                else
                    ena_re_s <= '1';
                    ena_man_s <= '1';
                    ena_r_s <= '1';
                    ns <= RE2;
                END IF;
            WHEN TE1 =>
                    ns <= TE2;
            WHEN TE2 =>
                if (message_sent = '1') then
                    ns <= ID;
                    ena_t_s <= '0';
			        ena_man_s <= '0';
                else
                    ns <= TE2;
                    ena_t_s <= '1';
			        ena_man_s <= '1';
			        ena_r_s <= '1';
                END IF;


		     WHEN HF =>
             ns <= ID;
					-- tell higher level controller in hard fault then send to align state?
                -- IF (host = '1') THEN
                --     ns <= HA;
                -- ELSE
                --     ns <= DA;
                -- END IF;
			-- WHEN HA =>
            --     IF (aligned = '1') THEN
            --         ns <= ID;
            --     ELSE
            --         ns <= HA;
            --     END IF;

			-- WHEN DA =>
            --     IF (aligned = '1') THEN
            --         ns <= ID;
            --     ELSE
            --         ns <= DA;
            --     END IF;

            WHEN OTHERS =>
                ns <= RT;


        END CASE;
    END PROCESS comb_proc;

END ARCHITECTURE rtl;