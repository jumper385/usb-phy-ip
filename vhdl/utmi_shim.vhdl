library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity utmi_shim is
	-- utmi <=>
	port (
		clk_i : in std_logic;
		rst_i : in std_logic;

		-- utmi interface
		utmi_data_tx_out_o : out std_logic_vector(7 downto 0);
		utmi_tx_valid_o : out std_logic;
		utmi_tx_ready_i : in std_logic;
		utmi_data_rx_in_i : in std_logic_vector(7 downto 0);
		utmi_rx_valid_i : in std_logic;
		utmi_rx_active_i : in std_logic;
		utmi_rx_error_i : in std_logic;

		-- rx path shim interface
		shim_rx_active_o : out std_logic;
		shim_rx_next_o : out std_logic;
		shim_rx_data_o : out std_logic_vector(7 downto 0);

		-- tx path shim interface
		shim_tx_first_i : in std_logic;
		shim_tx_next_o : out std_logic;
		shim_tx_last_i : in std_logic;
		shim_tx_next_i : in std_logic;
		shim_tx_data_i : in std_logic_vector(7 downto 0);

		-- handshake fast path
		shim_hs_pid_o : out std_logic_vector(3 downto 0);
		shim_hs_det_o : out std_logic;
		shim_hs_send_ack_i : in std_logic

	);
end entity utmi_shim;

architecture rtl of utmi_shim is
	---------------
	--- RX PATH ---
	---------------
	type rx_state_type is (RX_IDLE, RX_ARMED, RX_UNARMED, RX_GET_PID);
	signal rx_cs, rx_ns : rx_state_type := RX_IDLE;
	signal rx_data_q : std_logic_vector(7 downto 0) := (others => '0');

	---------------
	--- RX PATH ---
	---------------

	-----------------
	--- HANDSHAKE ---
	-----------------
	type hs_state_type is (HS_IDLE, HS_SETUP_SEEN, HS_DATA_SEEN, HS_SEND_ACK, HS_IN_SEEN, HS_SEND_NAK);
	signal hs_cs, hs_ns : hs_state_type := HS_IDLE;

begin
	---------------
	--- RX PATH ---
	---------------
	rx_fsm: process (clk_i, rst_i) is
	begin
		if rst_i = '0' then
			rx_cs <= RX_IDLE;
		elsif rising_edge(clk_i) then
			rx_cs <= rx_ns;
		end if;
	end process rx_fsm;

	rx_ns_logic: process (rx_cs, utmi_rx_active_i, utmi_rx_valid_i) is
	begin
		case rx_cs is

			when RX_IDLE =>
				if utmi_rx_active_i = '1' then
					rx_ns <= RX_GET_PID;
				else
					rx_ns <= RX_IDLE;
				end if;

			when RX_GET_PID =>
				if utmi_rx_active_i = '1' then
					if utmi_rx_valid_i = '1' then
						rx_ns <= RX_ARMED;
					else 
						rx_ns <= rx_cs;
					end if;
				else
					rx_ns <= RX_IDLE;
				end if;

			when RX_ARMED =>
				if utmi_rx_active_i = '1' then
					rx_ns <= RX_ARMED;
				else
					rx_ns <= RX_UNARMED;
				end if;

			when RX_UNARMED =>
				if utmi_rx_active_i = '1' then
					rx_ns <= RX_ARMED;
				else
					rx_ns <= RX_IDLE;
				end if;

			when others =>
				rx_ns <= RX_IDLE;

		end case;
	end process rx_ns_logic;

	rx_combi_logic: process (rx_cs, utmi_rx_valid_i) is
	begin

		shim_rx_active_o <= '0';
		shim_rx_data_o <= (others => '0');
		shim_rx_next_o <= '0';
		shim_hs_pid_o <= (others => '0');
		shim_hs_det_o <= '0';

		case rx_cs is

			when RX_IDLE =>
				shim_rx_active_o <= '0';

			when RX_GET_PID =>
				shim_rx_active_o <= '1';
				if utmi_rx_valid_i = '1' then
					shim_hs_pid_o <= utmi_data_rx_in_i(7 downto 4);
					shim_hs_det_o <= '1';
				end if;

			when RX_ARMED =>
				shim_rx_next_o <= utmi_rx_valid_i;
				shim_rx_active_o <= '1';
				if utmi_rx_valid_i = '1' then
					shim_rx_data_o <= utmi_data_rx_in_i;
				end if;

			when RX_UNARMED =>
				shim_rx_active_o <= '0';

			when others => 
				shim_rx_active_o <= '0';
				shim_rx_next_o <= '0';

		end case;
	end process rx_combi_logic;

	---------------
	--- TX PATH ---
	---------------
	-- TODO: Complete TX Path

	-----------------
	--- HANDSHAKE ---
	-----------------
	hs_fsm: process (clk_i, rst_i) is 
	begin
		if rst_i = '0' then
			hs_cs <= HS_IDLE;	
		elsif rising_edge(clk_i) then
			hs_cs <= hs_ns;
		end if;
	end process;

	hs_ns_logic: process(hs_cs, shim_hs_det_o, shim_hs_pid_o, utmi_rx_active_i) is
	begin
		-- detect setup
		case hs_cs is
			when HS_IDLE =>
				if shim_hs_det_o = '1' then

					if shim_hs_pid_o = x"5" then
						hs_ns <= HS_SETUP_SEEN;

					elsif shim_hs_pid_o = x"6" then
						hs_ns <= HS_IN_SEEN;

					else
						hs_ns <= HS_IDLE;

					end if;
				else
					hs_ns <= HS_IDLE;
				end if;

			when HS_SETUP_SEEN =>
				if shim_hs_det_o = '1' and shim_hs_pid_o = x"C" then
					hs_ns <= HS_DATA_SEEN;
				else
					hs_ns <= HS_SETUP_SEEN;
				end if;

			when HS_DATA_SEEN =>
				if utmi_rx_active_i = '0' then
					hs_ns <= HS_SEND_ACK;
				else
					hs_ns <= HS_DATA_SEEN;
				end if;

			when HS_IN_SEEN =>
				if utmi_rx_active_i = '0' then
					if shim_hs_send_ack_i = '1' then
						hs_ns <= HS_SEND_ACK;
					else
						hs_ns <= HS_SEND_NAK;
					end if;
				else
					hs_ns <= HS_IN_SEEN;
				end if;

			when HS_SEND_ACK =>
				hs_ns <= HS_IDLE;

			when HS_SEND_NAK =>
				hs_ns <= HS_IDLE;

			when others =>
				hs_ns <= HS_IDLE;

		end case;
	end process hs_ns_logic;

	hs_combi_logic: process(hs_cs) is
	begin

		case hs_cs is	

			when HS_IDLE =>
				utmi_tx_valid_o <= '0';

			when HS_SEND_ACK =>
				utmi_tx_valid_o <= '1';
				utmi_data_tx_out_o <= x"D2";

			when HS_SEND_NAK =>
				utmi_tx_valid_o <= '1';
				utmi_data_tx_out_o <= x"5A";

			when others =>
				utmi_tx_valid_o <= '0';
				
		end case;
	end process hs_combi_logic;

end architecture rtl;
