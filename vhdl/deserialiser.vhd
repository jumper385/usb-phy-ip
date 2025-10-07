library IEEE;
use IEEE.std_logic_1164.all;
USE ieee.numeric_std.ALL;
USE IEEE.std_logic_signed.ALL;


entity deserialiser is
	generic(
		BITS : INTEGER := 12; -- Number of bits being encoded
		mlength : INTEGER := 11 -- Number of bits in the length message (not including the sync)
	);
	port (
		clk : in STD_LOGIC;
		rx_message : out STD_LOGIC_VECTOR(BITS-1 downto 0); -- data to load into RAM
		rx_length : out std_logic_vector (mlength-1 downto 0); -- Received length 
		byte_in : in STD_LOGIC_VECTOR(BITS-1 downto 0); -- byte from manchester_decoder
		wr_addr : out STD_LOGIC_VECTOR (mlength-1 downto 0); -- Address to RX_RAM
		rx_done : out STD_LOGIC; -- signal to LT controller
		reset : in STD_LOGIC; -- global reset
		byte_ready : in STD_LOGIC; -- byte ready from manchester_decoder
        rx_error : out STD_LOGIC; -- RE to LT controller
        ena_r : in STD_LOGIC; -- enable from LT controller
        tx_error : out STD_LOGIC -- TE to LT controller
	);
end entity deserialiser;

architecture rtl of deserialiser is
	signal internal : STD_LOGIC := '0';
	signal length_received_w : STD_LOGIC;
    signal rx_length_wr : STD_LOGIC_VECTOR(mlength-1 downto 0);
	signal r_count : STD_LOGIC_VECTOR (mlength-1 downto 0) := (others => '0');
begin
	process (clk) is
	begin
		if (clk'event and clk= '1') then
			if (reset = '0') then
				internal <= '0';
                r_count <= (others => '0');
				length_received_w <= '0';

			elsif ( ena_r = '1') then
                -- define the length
				if (length_received_w = '0') then
					if (byte_ready = '1') then
                        rx_length_wr <= byte_in (mlength-1 downto 0);
                        length_received_w <= '1';
                        r_count <= (others => '0');
                    else
                        length_received_w <= '0';
                    end if;
				else -- once the length is sent, start sending the message
                    case rx_length(mlength -1 downto mlength -4) is
                        when "1111" =>
                            tx_error <= '1';
                        when "1000"|"0010"|"0001"|"0100"|"0011"|"0110"|"0111"|"0101"|"0000" =>
                            if (r_count = rx_length_wr) then
                                rx_done <= '1';
                                r_count <= (others => '0');
                                length_received_w <= '0';
                            elsif(byte_ready = '1') then
                                rx_message <= byte_in;
                                r_count <= r_count + 1;
                            end if;
                        when others =>
                            rx_error <= '1';
                    end case;
                end if;
			else
				rx_error <= '0';
                tx_error <= '0';
                length_received_w <= '0';
                r_count <= (others => '0');
				rx_done <='0';
			end if;
		end if;
	end process;
	wr_addr <= r_count;
	rx_length <= rx_length_wr;
    end architecture;