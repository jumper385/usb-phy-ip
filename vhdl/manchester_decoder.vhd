library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity manchester_decoder is
	generic (
		OVERSAMPLE : natural := 8; -- oversample factor (must match PLL output)
		BAUD : natural := 18000000; -- Manchester bit rate
		BITS : INTEGER := 12 -- Number of bits being processed out
	);
	port (
		clk_ovs : in std_logic; -- oversample clock from PLL (OVERSAMPLE BAUD)
		reset : in std_logic;
		man_in : in std_logic; -- Manchester encoded input
		bit_valid : out std_logic; -- one-cycle pulse when bit_out is valid
		bit_out : out std_logic; -- decoded bit for debugging/testing
		byte_out : out std_logic_vector(BITS-1 downto 0);
		byte_ready : out std_logic -- pulse when byte_out is valid
	);
end entity manchester_decoder;

architecture rtl of manchester_decoder is
	signal man_sync : std_logic_vector(2 downto 0) := (others => '0');
	signal prev_level : std_logic := '0';
	signal tick_count : integer range 0 to OVERSAMPLE * 2 := 0;
	signal bit_cnt : integer range 0 to BITS-1 := 0;
	signal byte_shift : std_logic_vector(BITS-1 downto 0) := (others => '0');
	--signal prev_bit : std_logic := '1';

	signal bit_out_r : std_logic := '0';
	signal bit_valid_r : std_logic := '0';
	signal byte_ready_r : std_logic := '0';
	signal byte_out_r : std_logic_vector(BITS-1 downto 0) := (others => '0');
begin

	bit_out <= bit_out_r;
	bit_valid <= bit_valid_r;
	byte_ready <= byte_ready_r;
	byte_out <= byte_out_r;

	process (clk_ovs) is
		variable interval : integer;
	begin
		if rising_edge(clk_ovs) then
			if reset = '0' then
				man_sync <= (others => '0');
				prev_level <= '0';
				tick_count <= 0;
				bit_cnt <= 0;
				byte_shift <= (others => '0');
				bit_out_r <= '0';
				bit_valid_r <= '0';
				byte_ready_r <= '0';
				--prev_bit <= '1';
			else
				-- shift register for metastability protection
				man_sync <= man_sync(1 downto 0) & man_in;

				-- default outputs
				bit_valid_r <= '0';
				byte_ready_r <= '0';

				tick_count <= tick_count + 1;

				-- detect edge
				if man_sync(2) /= prev_level then
					interval := tick_count;
					tick_count <= 0;

					-- classify interval
					if
					interval > (OVERSAMPLE / 2 - 1) and interval < (OVERSAMPLE / 2 + 1) and
						prev_level /= bit_out_r then
						-- half-bit interval
						if prev_level = '0' and man_sync(2) = '1' then
							bit_out_r <= '1'; -- low high = 1
						else
							bit_out_r <= '0'; -- high low = 0
						end if;
						bit_valid_r <= '1';
						--prev_bit <= bit_out_r;
						byte_shift <= byte_shift(BITS-2 downto 0) & man_sync(2);
						if bit_cnt = BITS-1 then
							byte_out_r <= byte_shift(BITS-2 downto 0) & man_sync(2);
							byte_ready_r <= '1';
							bit_cnt <= 0;
						else
							bit_cnt <= bit_cnt + 1;

						end if;


					elsif
					interval > (OVERSAMPLE - 1) and interval < (OVERSAMPLE + 1) and prev_level
						= bit_out_r then
						-- full-bit interval
						if prev_level = '0' and man_sync(2) = '1' then
							bit_out_r <= '1';
						else
							bit_out_r <= '0';
						end if;
						bit_valid_r <= '1';
						byte_shift <= byte_shift(BITS-2 downto 0) & man_sync(2);
						if bit_cnt = BITS-1 then
							byte_out_r <= byte_shift(BITS-2 downto 0) & man_sync(2);
							byte_ready_r <= '1';
							bit_cnt <= 0;
						else
							bit_cnt <= bit_cnt + 1;
						end if;
						--prev_bit <= bit_out_r;
					else
						-- out-of-sync, ignore
					end if;
				-- add a falling edge component which uses bit out_r to detect sync and send byte_received state
				-- then process the length as an 11 bit message
				-- then determine the next state
				-- integrate rx_error and tx_error detection
				

					prev_level <= man_sync(2);
				end if;
			end if;
		end if;
	end process;
end architecture rtl;