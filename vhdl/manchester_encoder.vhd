library IEEE;
use IEEE.std_logic_1164.all;


entity manchester_encoder is
	generic(
		BITS : INTEGER := 10 -- Number of bits being encoded
	);
	port (
		clk : in STD_LOGIC;
		message : in STD_LOGIC_VECTOR(BITS-1 downto 0);
		dout : out STD_LOGIC;
		reset : in STD_LOGIC;
		ena_t : in STD_LOGIC
	);
end entity manchester_encoder;

architecture arch of manchester_encoder is
	signal internal : STD_LOGIC := '0';
	signal parallel : STD_LOGIC_VECTOR(BITS-1 downto 0) := (others => '0');
begin
	process (clk, internal) is
		variable count : INTEGER range 0 to BITS;
	begin
		if (reset = '1') then
			dout <= '0';
			internal <= '0';
			parallel <= (others => '0');
			count := BITS-2;

		elsif (ena_t = '1)'then
			dout <= internal xor clk;
			if (clk'event and clk = '1') then
				count := count + 1;
				if (count = BITS-1) then
					parallel <= message;
				elsif (count = BITS) then
					count := 0;
				end if;
				internal <= parallel(count);
			end if;
		else
		end if;

	end process;

end architecture arch;
