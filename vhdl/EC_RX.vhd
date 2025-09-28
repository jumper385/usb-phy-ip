-- Library and Use statements for IEEE packages
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity EC_RX is

	port(
		EC_clk : in STD_LOGIC;
		EC_ENA : in STD_LOGIC;
		reset : in STD_LOGIC;
		LT_in : in STD_LOGIC_VECTOR (9 DOWNTO 0);
        EC_out : out STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
end EC_RX;

ARCHITECTURE EC_arch OF EC_RX IS
	-- insert local declarations here
BEGIN
	process (EC_clk, reset)
	
	begin
		IF reset = '1' THEN
			EC_out <= (others => '0');
		ELSIF rising_edge(EC_clk) THEN
			if EC_ENA = '1' THEN
				EC_out <= LT_in (7 DOWNTO 0);
			end if;
		end if;
	end process;


END EC_arch;