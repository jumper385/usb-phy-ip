library ieee;
use ieee.std_logic_1164.all;

entity PLL_clk is
	port (
		ref_clk_i : in std_logic;
		rst_n_i : in std_logic;
		outcore_o : out std_logic;
		outglobal_o : out std_logic
	);
end entity PLL_clk;

architecture rtl of PLL_clk is

	component SB_PLL40_CORE is
		generic (

            -- fout = fin * (DIVF + 1) / (2^DIVQ * (DIVR + 1))

			FEEDBACK_PATH : string := "SIMPLE";
			PLLOUT_SELECT : string := "GENCLK";
			DIVR : integer := 3;
			DIVF : integer := 43;
			DIVQ : integer := 5;
			FILTER_RANGE : integer := 4
		);
		port (
			REFERENCECLK : in std_logic;
			PLLOUTCORE : out std_logic;
			PLLOUTGLOBAL : out std_logic;
			EXTFEEDBACK : in std_logic;
			DYNAMICDELAY : in std_logic_vector(7 downto 0);
			LOCK : out std_logic;
			BYPASS : in std_logic;
			RESETB : in std_logic
		);
	end component SB_PLL40_CORE;

begin

	pll_inst: component SB_PLL40_CORE
	port map (
		REFERENCECLK => ref_clk_i,
		PLLOUTCORE => outcore_o,
		PLLOUTGLOBAL => open,
		EXTFEEDBACK => '0',
		DYNAMICDELAY => (others => '0'),
		LOCK => open,
		BYPASS => '0',
		RESETB => rst_n_i
	);

end architecture rtl;
