library ieee;
use ieee.std_logic_1164.all;



entity top_tb is
end top_tb;

architecture arch of top_tb is


component top is
	port (
		tram_wr_en : in std_logic;
		reset : in std_logic;
		dout : out std_logic; -- manchester tx
        clk_100 : in std_logic; -- 100 MHz 
		tx_length : in std_logic_vector (10 downto 0);
		din : in std_logic -- manchester rx
	);
end component;

signal tram_wr_en : std_logic:='0';
signal reset : std_logic:='0';
signal dout : std_logic; 
signal din : std_logic;
signal clk_100 : std_logic:='0';
signal dud : std_logic;
signal tram : std_logic;
signal dud2 : std_logic;
signal tx_length1 : std_logic_vector (10 downto 0);
signal tx_length2 : std_logic_vector (10 downto 0);

begin

dut : top
port map (
	tram_wr_en =>tram_wr_en, 
	reset => reset,
	dout=> dout,
	din => dud,
	clk_100=>clk_100,
	tx_length=> tx_length1
	
);

dut2 : top
port map (
	tram_wr_en =>tram, 
	reset => reset,
	dout=> dud2,
	din => din,
	clk_100=>clk_100,
	tx_length=>tx_length2
	
);

clk_100 <= not clk_100 after 5 ns;
tram <= '0';

reset <= '1' after 1 ns;
tram_wr_en <= '1' after 33 ns, '0' after 550 ns,'1' after 11000 ns, '0' after 11550 ns;
din<= dout;
dud<=dud2;
tx_length1<= "00000000111";
tx_length2<= "10110000000";
end architecture;