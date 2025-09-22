--======================================================================================--
--          Verilog to VHDL conversion by Martin Neumann martin@neumnns-mail.de         --
--                                                                                      --
--          ///////////////////////////////////////////////////////////////////         --
--          //                                                               //         --
--          //  USB 1.1 PHY                                                  //         --
--          //  TX                                                           //         --
--          //                                                               //         --
--          //                                                               //         --
--          //  Author: Rudolf Usselmann                                     //         --
--          //          rudi@asics.ws                                        //         --
--          //                                                               //         --
--          //                                                               //         --
--          //  Downloaded from: http://www.opencores.org/cores/usb_phy/     //         --
--          //                                                               //         --
--          ///////////////////////////////////////////////////////////////////         --
--          //                                                               //         --
--          //  Copyright (C) 2000-2002 Rudolf Usselmann                     //         --
--          //                          www.asics.ws                         //         --
--          //                          rudi@asics.ws                        //         --
--          //                                                               //         --
--          //  This source file may be used and distributed without         //         --
--          //  restriction provided that this copyright statement is not    //         --
--          //  removed from the file and that any derivative work contains  //         --
--          //  the original copyright notice and the associated disclaimer. //         --
--          //                                                               //         --
--          //      THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY      //         --
--          //  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED    //         --
--          //  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS    //         --
--          //  FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR       //         --
--          //  OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,          //         --
--          //  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES     //         --
--          //  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE    //         --
--          //  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR         //         --
--          //  BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF   //         --
--          //  LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT   //         --
--          //  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT   //         --
--          //  OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE          //         --
--          //  POSSIBILITY OF SUCH DAMAGE.                                  //         --
--          //                                                               //         --
--          ///////////////////////////////////////////////////////////////////         --
--======================================================================================--
--                                                                                      --
-- Change history                                                                       --
-- +-------+-----------+-------+------------------------------------------------------+ --
-- | Vers. | Date      | Autor | Comment                                              | --
-- +-------+-----------+-------+------------------------------------------------------+ --
-- |  2.0  | 3 Jul 2016|  MN   | Changed eop logic due to USB spec violation          | --
-- |  1.1  |23 Apr 2011|  MN   | Added missing 'rst' in process sensitivity lists     | --
-- |       |           |       | Added ELSE constructs in next_state process to       | --
-- |       |           |       |   prevent an undesired latch implementation.         | --
-- |  1.0  |04 Feb 2011|  MN   | Initial version                                      | --
--======================================================================================--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity usb_tx_phy is
	port (
		clk : in STD_LOGIC;
		rst : in STD_LOGIC;
		fs_ce : in STD_LOGIC;
		phy_mode : in STD_LOGIC; -- HIGH level for differential IO mode (else single-ended)
		-- Transciever Interface
		txdp, txdn, txoe : out STD_LOGIC;
		-- UTMI Interface
		DataOut_i : in STD_LOGIC_VECTOR(7 downto 0);
		TxValid_i : in STD_LOGIC;
		TxReady_o : out STD_LOGIC
	);
end entity usb_tx_phy;

architecture RTL of usb_tx_phy is

	signal hold_reg : STD_LOGIC_VECTOR(7 downto 0);
	signal ld_data : STD_LOGIC;
	signal ld_data_d : STD_LOGIC;
	signal ld_sop_d : STD_LOGIC;
	signal bit_cnt : STD_LOGIC_VECTOR(2 downto 0);
	signal sft_done_e : STD_LOGIC;
	signal any_eop_state : STD_LOGIC;
	signal append_eop : STD_LOGIC;
	signal data_xmit : STD_LOGIC;
	signal hold_reg_d : STD_LOGIC_VECTOR(7 downto 0);
	signal one_cnt : STD_LOGIC_VECTOR(2 downto 0);
	signal sd_bs_o : STD_LOGIC;
	signal sd_nrzi_o : STD_LOGIC;
	signal sd_raw_o : STD_LOGIC;
	signal sft_done : STD_LOGIC;
	signal sft_done_r : STD_LOGIC;
	signal state : STD_LOGIC_VECTOR(3 downto 0);
	signal stuff : STD_LOGIC;
	signal tx_ip : STD_LOGIC;
	signal tx_ip_sync : STD_LOGIC;
	signal txoe_r1, txoe_r2 : STD_LOGIC;

	constant IDLE_STATE : STD_LOGIC_VECTOR(3 downto 0) := "0000";
	constant SOP_STATE : STD_LOGIC_VECTOR(3 downto 0) := "0001";
	constant DATA_STATE : STD_LOGIC_VECTOR(3 downto 0) := "0010";
	constant WAIT_STATE : STD_LOGIC_VECTOR(3 downto 0) := "0011";
	constant EOP0_STATE : STD_LOGIC_VECTOR(3 downto 0) := "1000";
	constant EOP1_STATE : STD_LOGIC_VECTOR(3 downto 0) := "1001";
	constant EOP2_STATE : STD_LOGIC_VECTOR(3 downto 0) := "1010";
	constant EOP3_STATE : STD_LOGIC_VECTOR(3 downto 0) := "1011";
	constant EOP4_STATE : STD_LOGIC_VECTOR(3 downto 0) := "1100";
	constant EOP5_STATE : STD_LOGIC_VECTOR(3 downto 0) := "1101";

begin

	--======================================================================================--
	-- Misc Logic                                                                         --
	--======================================================================================--

	p_TxReady_o: process (clk, rst) is
	begin
		if rst = '0' then
			TxReady_o <= '0';
		elsif rising_edge(clk) then
			TxReady_o <= ld_data_d and TxValid_i;
		end if;
	end process p_TxReady_o;

	p_ld_data: process (clk) is
	begin
		if rising_edge(clk) then
			ld_data <= ld_data_d;
		end if;
	end process p_ld_data;

	--======================================================================================--
	-- Transmit in progress indicator                                                     --
	--======================================================================================--

	p_tx_ip: process (clk, rst) is
	begin
		if rst = '0' then
			tx_ip <= '0';
		elsif rising_edge(clk) then
			if ld_sop_d = '1' then
				tx_ip <= '1';
			elsif append_eop = '1' then
				tx_ip <= '0';
			end if;
		end if;
	end process p_tx_ip;

	p_tx_ip_sync: process (clk, rst) is
	begin
		if rst = '0' then
			tx_ip_sync <= '0';
		elsif rising_edge(clk) then
			if fs_ce = '1' then
				tx_ip_sync <= tx_ip;
			end if;
		end if;
	end process p_tx_ip_sync;

	-- data_xmit helps us to catch cases where TxValid drops due to
	-- packet END and then gets re-asserted as a new packet starts.
	-- We might not see this because we are still transmitting.
	-- data_xmit should solve those cases ...
	p_data_xmit: process (clk, rst) is
	begin
		if rst = '0' then
			data_xmit <= '0';
		elsif rising_edge(clk) then
			if TxValid_i = '1' and tx_ip = '0' then
				data_xmit <= '1';
			elsif TxValid_i = '0' then
				data_xmit <= '0';
			end if;
		end if;
	end process p_data_xmit;

	--======================================================================================--
	-- Shift Register                                                                     --
	--======================================================================================--

	p_bit_cnt: process (clk, rst) is
	begin
		if rst = '0' then
			bit_cnt <= "000";
		elsif rising_edge(clk) then
			if tx_ip_sync = '0' then
				bit_cnt <= "000";
			elsif fs_ce = '1' and stuff = '0' then
				bit_cnt <= bit_cnt + 1;
			end if;
		end if;
	end process p_bit_cnt;

	p_sd_raw_o: process (clk) is
	begin
		if rising_edge(clk) then
			if tx_ip_sync = '0' then
				sd_raw_o <= '0';
			else
				sd_raw_o <= hold_reg_d(CONV_INTEGER(UNSIGNED(bit_cnt)));
			end if;
		end if;
	end process p_sd_raw_o;

	p_sft_done: process (clk, rst) is
	begin
		if rst = '0' then
			sft_done <= '0';
			sft_done_r <= '0';
		elsif rising_edge(clk) then
			if bit_cnt = "111" then
				sft_done <= not stuff;
			else
				sft_done <= '0';
			end if;
			sft_done_r <= sft_done;
		end if;
	end process p_sft_done;

	sft_done_e <= sft_done and not sft_done_r;

	-- Out Data Hold Register
	p_hold_reg: process (clk, rst) is
	begin
		if rst = '0' then
			hold_reg <= X"00";
			hold_reg_d <= X"00";
		elsif rising_edge(clk) then
			if ld_sop_d = '1' then
				hold_reg <= X"80";
			elsif ld_data = '1' then
				hold_reg <= DataOut_i;
			end if;
			hold_reg_d <= hold_reg;
		end if;
	end process p_hold_reg;

	--======================================================================================--
	-- Bit Stuffer                                                                        --
	--======================================================================================--

	p_one_cnt: process (clk, rst) is
	begin
		if rst = '0' then
			one_cnt <= "000";
		elsif rising_edge(clk) then
			if tx_ip_sync = '0' then
				one_cnt <= "000";
			elsif fs_ce = '1' then
				if sd_raw_o = '0' or stuff = '1' then
					one_cnt <= "000";
				else
					one_cnt <= one_cnt + 1;
				end if;
			end if;
		end if;
	end process p_one_cnt;

	stuff <= '1' when one_cnt = "110" else '0';

	p_sd_bs_o: process (clk, rst) is
	begin
		if rst = '0' then
			sd_bs_o <= '0';
		elsif rising_edge(clk) then
			if fs_ce = '1' then
				if tx_ip_sync = '0' then
					sd_bs_o <= '0';
				else
					if stuff = '1' then
						sd_bs_o <= '0';
					else
						sd_bs_o <= sd_raw_o;
					end if;
				end if;
			end if;
		end if;
	end process p_sd_bs_o;

	--======================================================================================--
	-- NRZI Encoder                                                                       --
	--======================================================================================--

	p_sd_nrzi_o: process (clk, rst) is
	begin
		if rst = '0' then
			sd_nrzi_o <= '1';
		elsif rising_edge(clk) then
			if tx_ip_sync = '0' or txoe_r1 = '0' then
				sd_nrzi_o <= '1';
			elsif fs_ce = '1' then
				if sd_bs_o = '1' then
					sd_nrzi_o <= sd_nrzi_o;
				else
					sd_nrzi_o <= not sd_nrzi_o;
				end if;
			end if;
		end if;
	end process p_sd_nrzi_o;

	--======================================================================================--
	-- Output Enable Logic                                                                --
	--======================================================================================--

	p_txoe: process (clk, rst) is
	begin
		if rst = '0' then
			txoe_r1 <= '0';
			txoe_r2 <= '0';
			txoe <= '1';
		elsif rising_edge(clk) then
			if fs_ce = '1' then
				txoe_r1 <= tx_ip_sync;
				txoe_r2 <= txoe_r1;
				txoe <= not (txoe_r1 or txoe_r2);
			end if;
		end if;
	end process p_txoe;

	--======================================================================================--
	-- Output Registers                                                                   --
	--======================================================================================--

	p_txdpn: process (clk, rst) is
	begin
		if rst = '0' then
			txdp <= '1';
			txdn <= '0';
		elsif rising_edge(clk) then
			if fs_ce = '1' then
				if phy_mode = '1' then
					txdp <= not append_eop and sd_nrzi_o;
					txdn <= not append_eop and not sd_nrzi_o;
				else
					txdp <= sd_nrzi_o;
					txdn <= append_eop;
				end if;
			end if;
		end if;
	end process p_txdpn;

	--======================================================================================--
	-- Tx Statemashine                                                                    --
	--======================================================================================--

	any_eop_state <= state(3);

	p_state: process (clk, rst) is
	begin
		if rst = '0' then
			state <= IDLE_STATE;
		elsif rising_edge(clk) then
			if any_eop_state = '0' then
				case (state) is
					when IDLE_STATE =>
						if TxValid_i = '1' then
							state <= SOP_STATE;
						end if;
					when SOP_STATE =>
						if sft_done_e = '1' then
							state <= DATA_STATE;
						end if;
					when DATA_STATE =>
						if data_xmit = '0' and sft_done_e = '1' then
							if one_cnt = "101" and hold_reg_d(7) = '1' then
								state <= EOP0_STATE;
							else
								state <= EOP1_STATE;
							end if;
						end if;
					when WAIT_STATE =>
						if fs_ce = '1' then
							state <= IDLE_STATE;
						end if;
					when others =>
						state <= IDLE_STATE;
				end case;
			else
				if fs_ce = '1' then
					if state = EOP5_state then
						state <= WAIT_STATE;
					else
						state <= unsigned(state) + 1;
					end if;
				end if;
			end if;
		end if;
	end process p_state;

	append_eop <= '1' when state(3 downto 2) = "11" else '0'; -- EOP4_STATE OR EOP5_STATE
	ld_sop_d <= TxValid_i when state = IDLE_STATE else '0';
	ld_data_d <=
		sft_done_e when state = SOP_STATE or (state = DATA_STATE and data_xmit = '1')
		else '0';

end architecture RTL;
