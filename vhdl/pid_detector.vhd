library ieee;
use ieee.std_logic_1164.all;

entity pid_detector is
	port (
		utmi_din : in std_logic_vector(7 downto 0);
		utmi_rxvalid : in std_logic;
		utmi_rxactive : in std_logic;
		utmi_rxerror : in std_logic;

		pid_filter_i : in std_logic_vector(7 downto 0);
		pid_detected_o : out std_logic
	);
end pid_detector;

architecture rtl of pid_detector is

	signal pid_detected : std_logic;

begin

	pid_detected <= '1' when utmi_din(7 downto 0) = pid_filter_i(7 downto 0) else '0';
	pid_detected_o <= pid_detected and utmi_rxvalid;

end architecture;

