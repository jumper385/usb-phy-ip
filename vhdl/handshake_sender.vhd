LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

ENTITY handshake_sender IS
	PORT (
		en : IN STD_LOGIC;
		clk : IN STD_LOGIC;
		-- output to UTMI PHY
		utmi_dout_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		utmi_txvalid_o : OUT STD_LOGIC;

		-- control
		setup_detected_i : IN STD_LOGIC;
		data_detected_i : IN STD_LOGIC;
		in_detected_i : IN STD_LOGIC;
		utmi_txrdy_i : IN STD_LOGIC;
		
		-- debug
		dbg_state_o : out std_logic_vector(2 downto 0)
	);
END ENTITY;

ARCHITECTURE rtl OF handshake_sender IS
	TYPE fsm_states is (IDLE, SEND_ACK, SEND_NAK);
	SIGNAL cs, ns : fsm_states;

	constant PID_ACK   : std_logic_vector(7 downto 0) := x"D2";
	constant PID_NAK   : std_logic_vector(7 downto 0) := x"5A";
BEGIN

	-- sequential 
	process (clk, en)
	begin
		if en = '1' then
			cs <= IDLE;
		elsif rising_edge(clk) then
			cs <= ns;
		end if;
	end process;

	-- combinatorial 
	process (cs, setup_detected_i, data_detected_i, in_detected_i, utmi_txrdy_i)
	begin
		case cs is
			when IDLE =>
				utmi_dout_o <= x"00";
				utmi_txvalid_o <= '0';
				if setup_detected_i='1' or data_detected_i='1' then
					ns <= SEND_ACK;
				elsif in_detected_i='1' then
					ns <= SEND_NAK;
				else
					ns <= IDLE;
				end if;
			
			when SEND_ACK =>
				utmi_dout_o <= PID_ACK;
				utmi_txvalid_o <= '1';
				
				if not utmi_txrdy_i then
					ns <= IDLE;
				else
					ns <= cs;
				end if;

			when SEND_NAK =>
				utmi_dout_o <= PID_NAK;
				utmi_txvalid_o <= '1';
				
				if not utmi_txrdy_i then
					ns <= IDLE;
				else
					ns <= cs;
				end if;

			when others => 
				utmi_dout_o <= x"00";
				utmi_txvalid_o <= '0';
				ns <= IDLE;
		end case;
	end process;
	
	dbg_state_o <= std_logic_vector(to_unsigned(fsm_states'pos(cs), 3));

END ARCHITECTURE;
