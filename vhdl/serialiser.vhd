library IEEE;
use IEEE.std_logic_1164.all;
USE ieee.numeric_std.ALL;
USE IEEE.std_logic_signed.ALL;


entity serialiser is
	generic(
		BITS : INTEGER := 10; -- Number of bits being encoded
		mlength : INTEGER := 11 -- Number of bits in the length message (not including the sync)
	);
	port (
		clk : in STD_LOGIC;
		message : in STD_LOGIC_VECTOR(BITS-1 downto 0);
		tx_length : in std_logic_vector (mlength-1 downto 0);
		dout : out STD_LOGIC;
		rd_addr : out STD_LOGIC_VECTOR (mlength-1 downto 0);
		message_sent : out STD_LOGIC;
		reset : in STD_LOGIC;
		ena_t : in STD_LOGIC
	);
end entity serialiser;

architecture arch of serialiser is
	signal internal : STD_LOGIC := '0';
	signal parallel : STD_LOGIC_VECTOR(BITS-1 downto 0) := (others => '0');
	signal length_sent_w : STD_LOGIC;
	signal r_count : STD_LOGIC_VECTOR (mlength-1 downto 0) := (others => '0');
begin
	process (clk) is
		variable count : INTEGER range -1 to BITS;
		variable lencount : INTEGER range 0 to mlength;
	begin
		if (clk'event and clk= '1') then
			if (reset = '0') then
				internal <= '0';
				parallel <= (others => '0');
				count := BITS;
				lencount := mlength-1;
				length_sent_w <= '0';

			elsif (ena_t = '1') then
				if (length_sent_w = '0') then
					if (lencount = 1) then
						internal <= tx_length(lencount);
						r_count <= (others => '0');
					elsif (lencount = 0) then
						parallel <= message; -- load the message so the system is ready to send the message straight away
						internal <= tx_length(lencount);
						count := BITS;
						lencount := mlength;	
						length_sent_w <= '1';	
					else
						internal <= tx_length(lencount);
					end if;
					lencount := lencount - 1;
				else -- once the length is sent, start sending the message
					count := count -1;
					if (r_count > tx_length and count =-1) then
						message_sent <= '1';
						r_count <= (others => '0');
						parallel <= (others => '0');
					else
						if (count = -1) then
							count := BITS-1;
						elsif (count = 4) then
							r_count <= r_count + 1;
						elsif (count = 0) then
							parallel <= message;
						end if;
						internal <= parallel(count);
					end if;
				end if;
			else
				lencount := mlength-1;
				count := BITS;
				length_sent_w <= '0';
				internal <= '0';
				message_sent <='0';
			end if;
		end if;
	end process;
	rd_addr <= r_count;
	dout <= internal;
end architecture arch;
