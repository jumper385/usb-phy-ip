-- Library and Use statements for IEEE packages
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY EC_TX IS

	PORT (
		EC_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		EC_clk : IN STD_LOGIC;
		EC_ENA : IN STD_LOGIC;
		reset : IN STD_LOGIC;
		RAM_out : OUT STD_LOGIC_VECTOR (9 DOWNTO 0);
		RAM_ready : OUT STD_LOGIC
	);
END EC_TX;

ARCHITECTURE EC_arch OF EC_TX IS
	-- insert local declarations here
BEGIN
	PROCESS (EC_clk, reset)

	BEGIN
		IF reset = '1' THEN
			RAM_out <= (OTHERS => '0');
		ELSIF rising_edge(EC_clk) THEN
			IF EC_ENA = '1' THEN
				RAM_ready <= '1';
				RAM_out <= "01" & EC_in;
			END IF;
		END IF;
	END PROCESS;
END EC_arch;