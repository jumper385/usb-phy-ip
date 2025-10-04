library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity usb_phy is
	generic (
		usb_rst_det : boolean := TRUE
	);
	port (
		clk : in std_logic; -- 60 MHz
		rst : in std_logic;
		phy_tx_mode : in std_logic; -- HIGH level for differential io mode (else single-ended)
		usb_rst : out std_logic;
		-- Transciever Interface
		rxd, rxdp, rxdn : in std_logic;
		txdp, txdn, txoe : out std_logic;
		-- UTMI Interface
		DataOut_i : in std_logic_vector(7 downto 0);
		TxValid_i : in std_logic;
		TxReady_o : out std_logic;
		DataIn_o : out std_logic_vector(7 downto 0);
		RxValid_o : out std_logic;
		RxActive_o : out std_logic;
		RxError_o : out std_logic;
		LineState_o : out std_logic_vector(1 downto 0)
	);
end entity usb_phy;

architecture RTL of usb_phy is

	signal LineState : std_logic_vector(1 downto 0);
	signal fs_ce : std_logic;
	signal rst_cnt : std_logic_vector(4 downto 0);
	signal txoe_out : std_logic;
	signal usb_rst_out : std_logic := '0';

begin

	--======================================================================================--
	-- Misc Logic                                                                         --
	--======================================================================================--

	usb_rst <= usb_rst_out;
	LineState_o <= LineState;
	txoe <= txoe_out;

	--======================================================================================--
	-- TX Phy                                                                             --
	--======================================================================================--

	i_tx_phy: entity work.usb_tx_phy
	port map (
		clk => clk,
		rst => rst,
		fs_ce => fs_ce,
		phy_mode => phy_tx_mode,
		-- Transciever Interface
		txdp => txdp,
		txdn => txdn,
		txoe => txoe_out,
		-- UTMI Interface
		DataOut_i => DataOut_i,
		TxValid_i => TxValid_i,
		TxReady_o => TxReady_o
	);

	--======================================================================================--
	-- RX Phy and DPLL                                                                    --
	--======================================================================================--

	i_rx_phy: entity work.usb_rx_phy
	port map (
		clk => clk,
		rst => rst,
		fs_ce_o => fs_ce,
		-- Transciever Interface
		rxd => rxd,
		rxdp => rxdp,
		rxdn => rxdn,
		-- UTMI Interface
		DataIn_o => DataIn_o,
		RxValid_o => RxValid_o,
		RxActive_o => RxActive_o,
		RxError_o => RxError_o,
		RxEn_i => txoe_out,
		LineState => LineState
	);

	--======================================================================================--
	-- Generate an USB Reset if we see SE0 for at least 2.5uS                             --
	--======================================================================================--

	usb_rst_g: if usb_rst_det generate
		p_rst_cnt: process (clk, rst) is
		begin
			if rst = '0' then
				rst_cnt <= (others => '0');
			elsif rising_edge(clk) then
				if LineState /= "00" then
					rst_cnt <= (others => '0');
				elsif usb_rst_out = '0' and fs_ce = '1' then
					rst_cnt <= rst_cnt + 1;
				end if;
			end if;
		end process p_rst_cnt;

		p_usb_rst_out: process (clk) is
		begin
			if rising_edge(clk) then
				if rst_cnt = "11111" then
					usb_rst_out <= '1';
				else
					usb_rst_out <= '0';
				end if;
			end if;
		end process p_usb_rst_out;
	end generate;

end architecture RTL;
