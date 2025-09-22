library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

entity honeycomb_fs_phy is
	port (
		rst_i : in std_logic; -- low = reset; high = normal
		clk_48mhz_i : in std_logic; 
		fs_pu_o : out std_logic; -- output to pull up resistor; optional

		-- usb interface
		usb_dp_io : inout std_logic; -- ensure 1.5k pull up here 
		usb_dn_io : inout std_logic;
		
		-- utmi tx interface
		utmi_dout_i : in std_logic_vector(7 downto 0); -- stage tx data here
		utmi_txvalid_i : in std_logic; -- request to tx here; set high
		utmi_txrdy_o : out std_logic; -- high = transmitting state
		
		-- utmi rx interface
		utmi_din_o : out std_logic_vector(7 downto 0); -- all rx line data here
		utmi_rxvalid_o : out std_logic; -- high rx is good to read
		utmi_rxactive_o : out std_logic; -- high if rx'ing
		utmi_rxerror_o : out std_logic; -- high if error

		-- utmi debug interface
		utmi_line_state_o : out std_logic_vector(1 downto 0); -- probe bit 0 for usb state
		utmi_usb_rst_o : out std_logic -- high if usb phy is being reset
	);
end honeycomb_fs_phy;

architecture rtl of honeycomb_fs_phy is 

        COMPONENT usb_phy
                PORT (
                        clk : IN STD_LOGIC;
                        rst : IN STD_LOGIC;
                        phy_tx_mode : IN STD_LOGIC;
                        usb_rst : OUT STD_LOGIC;
                        rxd, rxdp, rxdn : IN STD_LOGIC;
                        txdp, txdn, txoe : OUT STD_LOGIC;
                        DataOut_i : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
                        TxValid_i : IN STD_LOGIC;
                        TxReady_o : OUT STD_LOGIC;
                        DataIn_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
                        RxValid_o : OUT STD_LOGIC;
                        RxActive_o : OUT STD_LOGIC;
                        RxError_o : OUT STD_LOGIC;
                        LineState_o : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)
                );
        END COMPONENT;

	signal rxdp, rxdn, txoe, txdp, txdn : std_logic;

begin

	u_phy : usb_phy 
	port map (
		clk => clk_48mhz_i,
		rst => rst_i,
		phy_tx_mode => '1', -- u can use in single ended mode but we wont...
		
		rxd => rxdp, -- used to retreive timing for the usb phy; rxdp will do
		rxdp => rxdp,
		rxdn => rxdn,
		txoe => txoe, -- used as tristate ctrl for usb phy inout pins
		txdp => txdp,
		txdn => txdn,
			
		DataOut_i => utmi_dout_i, 
		TxValid_i => utmi_txvalid_i, 	
		TxReady_o => utmi_txrdy_o, 
		
		DataIn_o => utmi_din_o, 
		RxValid_o => utmi_rxvalid_o,
		RxActive_o => utmi_rxactive_o,
		RxError_o => utmi_rxerror_o,

		LineState_o => utmi_line_state_o,
		usb_rst => utmi_usb_rst_o
	);
	
	-- tristate inference; ice40 may be better done with SB_IO
	-- testing shows this works though; a bit more agnostic
	-- this doesnt actually compile in any SB_IO... so assume 
	-- there is no buffering
	usb_dp_io <= txdp when txoe = '0' else 'Z';
	usb_dn_io <= txdn when txoe = '0' else 'Z';

	rxdp <= usb_dp_io;
	rxdn <= usb_dn_io;

	fs_pu_o <= '1'; -- dont route if not required; put into signal or smthn

end architecture;
