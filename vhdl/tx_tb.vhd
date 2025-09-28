-- Library and Use statements for IEEE packages
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.std_logic_unsigned.all;


entity tx_tb is

end entity tx_tb;

architecture arch of tx_tb is
	-- insert local declarations here
	signal wr_clk : STD_LOGIC := '0';
	signal rd_clk : STD_LOGIC := '0';
	signal reset : STD_LOGIC;
	signal wr_en : STD_LOGIC := '0';
	signal rd_en : STD_LOGIC := '0';
	signal wr_data : STD_LOGIC_VECTOR (9 downto 0) := "0000011111";
	signal rd_data : STD_LOGIC_VECTOR (9 downto 0);
	signal tx_length : STD_LOGIC_VECTOR (10 downto 0);

component TX_RAM is
	port (
		-- enter port declarations here
		wr_clk : in STD_LOGIC;
		rd_clk : in STD_LOGIC;
		reset : in STD_LOGIC;
		wr_en : in STD_LOGIC;
		rd_en : in STD_LOGIC;
		wr_data : in STD_LOGIC_VECTOR (9 downto 0);
		rd_data : out STD_LOGIC_VECTOR (9 downto 0);
		tx_length : in STD_LOGIC_VECTOR (10 downto 0)
	);
end component;
begin

tx_ramm : TX_RAM
port map(wr_clk=>wr_clk, rd_clk=>rd_clk, reset=>reset,wr_en=>wr_en,rd_en=>rd_en,wr_data=>wr_data,rd_data=>rd_data,tx_length=>tx_length);

rd_clk <= not rd_clk after 5 ns;
wr_clk <= not wr_clk after 5 ns;
reset <= '1', '0' after 10 ns;
wr_en <= '1' after 20 ns, '0' after 500 ns;
rd_en <= '1' after 30 ns, '0' after 510 ns;
tx_length <= "00000011111";
--wr_data <= "1010101010", "1010101010" after 40 ns, "1111111111" after 50 ns, "0000000000" after 60 ns;

process (wr_clk)
begin
 if falling_edge(wr_clk) then
	wr_data <= wr_data + 1;
	end if;
end process;


end architecture arch;
