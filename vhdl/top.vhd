library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
	port (
		clk_60 : in std_logic; 
		rst_n : in std_logic;
		usb_dp : inout std_logic;
		usb_dn : inout std_logic;
		led : out std_logic
	);
end entity;

architecture rtl of top is

	component usb_phy is 
		  port (
		      clk              : in  std_logic;
		      rst              : in  std_logic;
		      phy_tx_mode      : in  std_logic;
		      usb_rst          : out std_logic;
		      -- Transciever Interface
		      rxd, rxdp, rxdn  : in  std_logic;
		      txdp, txdn, txoe : out std_logic;
		      -- UTMI Interface
		      DataOut_i        : in  std_logic_vector(7 downto 0);
		      TxValid_i        : in  std_logic;
		      TxReady_o        : out std_logic;
		      DataIn_o         : out std_logic_vector(7 downto 0);
		      RxValid_o        : out std_logic;
		      RxActive_o       : out std_logic;
		      RxError_o        : out std_logic;
		      LineState_o      : out std_logic_vector(1 downto 0)
		);
	end component;

	signal txdp, txdn, txoe : std_logic;
	signal rxdp, rxdn, rxd : std_logic;

	signal utmi_dout : std_logic_vector(7 downto 0);
	signal utmi_txvalid : std_logic;
	signal utmi_txrdy : std_logic;
	signal utmi_din : std_logic_vector(7 downto 0);
	signal utmi_rxvalid : std_logic;
	signal utmi_rxactive : std_logic;
	signal utmi_rxerror : std_logic;
	signal utmi_line_state : std_logic_vector(1 downto 0);
	signal utmi_usb_rst : std_logic;

begin

	usb_dp <= txdp when txoe = '0' else 'Z';
	usb_dn <= txdn when txoe = '0' else 'Z';
	rxdp <= usb_dp;
	rxdn <= usb_dn;
	rxd <= usb_dp;

	u_phy: usb_phy 
		port map (
			clk => clk_60, 
		       	rst => rst_n,
			phy_tx_mode => '1',
			usb_rst => utmi_usb_rst,
			rxd => rxd, 
			rxdp => rxdp, 
			rxdn => rxdn, 
			txdp => txdp, 
			txdn => txdn, 
			txoe => txoe, 
			DataOut_i => utmi_dout, 
			TxValid_i => utmi_txvalid, 
			TxReady_o => utmi_txrdy, 
			DataIn_o => utmi_din, 
			RxValid_o => utmi_rxvalid, 
			RxActive_o => utmi_rxactive,
		      	RxError_o => utmi_rxerror,
		    	LineState_o => utmi_line_state
		);
	
end rtl;
