library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity handshake_sender is
	port (
		en : in STD_LOGIC;
		clk : in STD_LOGIC;
		-- output to UTMI PHY
		utmi_dout_o : out STD_LOGIC_VECTOR(7 downto 0);
		utmi_txvalid_o : out STD_LOGIC;

		-- control
		setup_detected_i : in STD_LOGIC;
		data_detected_i : in STD_LOGIC;
		in_detected_i : in STD_LOGIC;
		utmi_txrdy_i : in STD_LOGIC;

		-- debug
		dbg_state_o : out std_logic_vector(2 downto 0)
	);
end entity handshake_sender;

architecture rtl of handshake_sender is
	type fsm_states is (IDLE, SEND_ACK, SEND_NAK);
	signal cs, ns : fsm_states;

	constant PID_ACK : std_logic_vector(7 downto 0) := x"D2";
	constant PID_NAK : std_logic_vector(7 downto 0) := x"5A";
begin

	-- sequential
	process (clk, en) is
	begin
		if en = '1' then
			cs <= IDLE;
		elsif rising_edge(clk) then
			cs <= ns;
		end if;
	end process;

	-- combinatorial
	process (cs, setup_detected_i, data_detected_i, in_detected_i, utmi_txrdy_i) is
	begin
		case cs is
			when IDLE =>
				utmi_dout_o <= x"00";
				utmi_txvalid_o <= '0';
				if setup_detected_i = '1' or data_detected_i = '1' then
					ns <= SEND_ACK;
				elsif in_detected_i = '1' then
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

end architecture rtl;
