-- utmi_shim.vhdl
-- Tiny UTMI adapter: normalizes UTMI to clean streams and provides a 1-byte handshake fast-path.
-- Henry-ready :)  (host/device agnostic)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity utmi_shim is
    generic (
        -- Some PHYs expose TxReady; set to false if not present (assumed always '1')
        HAS_TXREADY      :     boolean                      := true
    );
    port (
        -- Clock/Reset
        clk_i            : in  std_logic;
        rst_n_i          : in  std_logic;

        -- ========== UTMI RX ==========
        utmi_data_in_i   : in  std_logic_vector(7 downto 0);
        utmi_rxvalid_i   : in  std_logic;
        utmi_rxactive_i  : in  std_logic;
        utmi_rxerror_i   : in  std_logic;

        -- ========== UTMI TX ==========
        utmi_data_out_o  : out std_logic_vector(7 downto 0);
        utmi_txvalid_o   : out std_logic;
        utmi_txready_i   : in  std_logic; -- ignored if HAS_TXREADY=false

        -- Optional (unused internally; here for completeness)
        utmi_linestate_i : in  std_logic_vector(1 downto 0) := (others => '0');

        -- ========== Clean RX stream (device->core) ==========
        rx_tdata_o       : out std_logic_vector(7 downto 0);
        rx_tvalid_o      : out std_logic; -- asserts with valid rx_tdata_o
        rx_tready_i      : in  std_logic; -- backpressure (tie '1' to accept all)
        rx_tfirst_o      : out std_logic; -- 1-cycle pulse at first byte of packet
        rx_tlast_o       : out std_logic; -- 1-cycle pulse at last byte of packet
        rx_pkt_err_o     : out std_logic; -- 1-cycle pulse at EOP indicating any RxError in pkt

        -- ========== Clean TX stream (core->device) ==========
        -- DATA path (payload stream). Provide DATAx via tx_pid_i when starting (with tx_tfirst_i).
        tx_tdata_i       : in  std_logic_vector(7 downto 0);
        tx_tvalid_i      : in  std_logic;
        tx_tready_o      : out std_logic;
        tx_tfirst_i      : in  std_logic; -- assert with first payload byte
        tx_tlast_i       : in  std_logic; -- assert with last payload byte
        tx_pid_i         : in  std_logic_vector(3 downto 0); -- low nibble of DATA PID: 0011=DATA0,1011=DATA1,...

        -- Handshake fast-path (single byte; no payload/CRC)
        tx_hs_req_i      : in  std_logic; -- pulse to send a handshake now
        tx_hs_pid_i      : in  std_logic_vector(3 downto 0); -- low nibble: 0010=ACK,1010=NAK,1110=STALL,0110=NYET

        -- Status/Debug
        tx_busy_o        : out std_logic; -- 1 while handshake/data pkt being transmitted
        rx_in_pkt_o      : out std_logic -- mirrors UTMI RxActive for visibility
    );
end entity utmi_shim;

architecture rtl of utmi_shim is

    ---------------------------------------------------------------------------
    -- Helpers
    ---------------------------------------------------------------------------
    function txready_true return std_logic is
    begin
        return '1';
    end function txready_true;

    -- Selectable txready based on generic
    signal txready_s      : std_logic;

    -- Build full PID byte from low nibble
    function pid_full (lo : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable hi : std_logic_vector(3 downto 0);
    begin
        hi                                        := not lo;
        return hi & lo;
    end function pid_full;

    -- USB CRC16 (poly x^16 + x^15 + x^2 + 1), byte-wise, init=0xFFFF, LSB-first per byte
    function crc16_next (crc : std_logic_vector(15 downto 0); d : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable c      : unsigned(15 downto 0) := unsigned(crc);
        variable bit_in : std_logic;
    begin
        -- process 8 bits, LSB first
        for i in 0 to 7 loop
            bit_in                                := c(0) xor d(i);                   -- incoming bit XOR current LSB of CRC
            c                                     := c srl 1;
            if bit_in = '1' then
                c                                 := c xor to_unsigned(16#A001#, 16); -- reversed poly for right-shift impl
            end if;
        end loop;
        return std_logic_vector(c);
    end function crc16_next;

    ---------------------------------------------------------------------------
    -- RX path
    ---------------------------------------------------------------------------
    type rx_state_t is (RX_IDLE, RX_INPKT);
    signal rx_state       : rx_state_t                    := RX_IDLE;
    signal rx_err_sticky  : std_logic                     := '0';
    signal rx_first_sent  : std_logic                     := '0';

    signal rx_tdata_q     : std_logic_vector(7 downto 0)  := (others => '0');
    signal rx_tvalid_q    : std_logic                     := '0';
    signal rx_tfirst_q    : std_logic                     := '0';
    signal rx_tlast_q     : std_logic                     := '0';
    signal rx_pkt_err_q   : std_logic                     := '0';

    ---------------------------------------------------------------------------
    -- TX path
    ---------------------------------------------------------------------------
    type tx_state_t is (
        TX_IDLE,
        TX_HS_SEND,                                                                   -- sending handshake PID
        TX_HS_WAITACC,                                                                -- wait accept of handshake byte
        TX_DATA_PID,                                                                  -- send DATAx PID byte
        TX_DATA_PAYLOAD,                                                              -- stream payload bytes & compute CRC16
        TX_DATA_CRC0,                                                                 -- send CRC16 LSB
        TX_DATA_CRC1,                                                                 -- send CRC16 MSB
        TX_DATA_WAITACC                                                               -- wait accept of the last byte (used if no txready)
    );

    signal tx_state       : tx_state_t                    := TX_IDLE;

    signal txbusy_q       : std_logic                     := '0';
    signal utmi_dout_q    : std_logic_vector(7 downto 0)  := (others => '0');
    signal utmi_tvalid_q  : std_logic                     := '0';

    signal hs_pending     : std_logic                     := '0';
    signal hs_pid_byte    : std_logic_vector(7 downto 0)  := (others => '0');

    signal data_pid_byte  : std_logic_vector(7 downto 0)  := (others => '0');
    signal crc16_reg      : std_logic_vector(15 downto 0) := (others => '1');         -- init 0xFFFF
    signal crc16_final    : std_logic_vector(15 downto 0) := (others => '0');

    -- Backpressure from shim towards core TX payload
    signal tx_tready_q    : std_logic                     := '0';

begin

    -- Map txready_s depending on generic
    txready_s <= (utmi_txready_i) when HAS_TXREADY else txready_true;

    -- Outputs
    utmi_data_out_o                               <= utmi_dout_q;
    utmi_txvalid_o                                <= utmi_tvalid_q;

    rx_tdata_o                                    <= rx_tdata_q;
    rx_tvalid_o                                   <= rx_tvalid_q;
    rx_tfirst_o                                   <= rx_tfirst_q;
    rx_tlast_o                                    <= rx_tlast_q;
    rx_pkt_err_o                                  <= rx_pkt_err_q;

    tx_busy_o                                     <= txbusy_q;
    rx_in_pkt_o                                   <= utmi_rxactive_i;

    tx_tready_o                                   <= tx_tready_q;

    ---------------------------------------------------------------------------
    -- RX FSM: turn UTMI RxActive/Valid/Error into a clean stream + SOP/EOP + per-packet error
    ---------------------------------------------------------------------------
    process (clk_i) is
    begin
        if rising_edge(clk_i) then
            if rst_n_i = '0' then
                rx_state                          <= RX_IDLE;
                rx_err_sticky                     <= '0';
                rx_first_sent                     <= '0';
                rx_tdata_q                        <= (others => '0');
                rx_tvalid_q                       <= '0';
                rx_tfirst_q                       <= '0';
                rx_tlast_q                        <= '0';
                rx_pkt_err_q                      <= '0';
            else
                -- defaults each cycle
                rx_tvalid_q                       <= '0';
                rx_tfirst_q                       <= '0';
                rx_tlast_q                        <= '0';
                rx_pkt_err_q                      <= '0';

                case rx_state is
                    when RX_IDLE =>
                        rx_err_sticky             <= '0';
                        rx_first_sent             <= '0';
                        if utmi_rxactive_i = '1' then
                            rx_state              <= RX_INPKT;
                        end if;

                    when RX_INPKT =>
                        -- capture any error during the packet
                        if utmi_rxerror_i = '1' then
                            rx_err_sticky         <= '1';
                        end if;

                        -- stream bytes only when RxValid=1
                        if utmi_rxvalid_i = '1' then
                            -- if backpressure, we drop the byte and mark error (simplest policy)
                            if rx_tready_i = '1' then
                                rx_tdata_q        <= utmi_data_in_i;
                                rx_tvalid_q       <= '1';
                                if rx_first_sent = '0' then
                                    rx_tfirst_q   <= '1';
                                    rx_first_sent <= '1';
                                end if;
                            else
                                rx_err_sticky     <= '1';
                            end if;
                        end if;

                        -- EOP
                        if utmi_rxactive_i = '0' then
                            rx_tlast_q            <= '1';
                            rx_pkt_err_q          <= rx_err_sticky;
                            rx_state              <= RX_IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- TX path arbitration: handshakes get priority if requested while idle.
    -- Data path drives when tx_tfirst_i/tx_tvalid_i indicate a payload start.
    ---------------------------------------------------------------------------

    process (clk_i) is
        variable next_crc : std_logic_vector(15 downto 0);
    begin
        if rising_edge(clk_i) then
            if rst_n_i = '0' then
                tx_state                          <= TX_IDLE;
                utmi_dout_q                       <= (others => '0');
                utmi_tvalid_q                     <= '0';
                txbusy_q                          <= '0';
                hs_pending                        <= '0';
                hs_pid_byte                       <= (others => '0');
                data_pid_byte                     <= (others => '0');
                crc16_reg                         <= (others => '1');                 -- 0xFFFF
                crc16_final                       <= (others => '0');
                tx_tready_q                       <= '0';
            else
                -- Defaults
                utmi_tvalid_q                     <= '0';
                tx_tready_q                       <= '0';

                -- Latch incoming handshake request if idle
                if tx_hs_req_i = '1' and tx_state = TX_IDLE then
                    hs_pending                    <= '1';
                    hs_pid_byte                   <= pid_full(tx_hs_pid_i);
                end if;

                case tx_state is

                    when TX_IDLE =>
                        txbusy_q                  <= '0';

                        -- Prefer handshake if pending
                        if hs_pending = '1' then
                            -- Try to send now
                            if txready_s = '1' then
                                utmi_dout_q       <= hs_pid_byte;
                                utmi_tvalid_q     <= '1';
                                txbusy_q          <= '1';
                                hs_pending        <= '0';
                                tx_state          <= TX_HS_WAITACC;
                            else
                                -- hold; we'll retry next cycle
                                tx_state          <= TX_HS_SEND;
                                txbusy_q          <= '1';
                            end if;

                            -- Else check for DATA path start
                        elsif (tx_tvalid_i = '1' and tx_tfirst_i = '1') then
                            data_pid_byte         <= pid_full(tx_pid_i);
                            crc16_reg             <= (others => '1');                 -- reset 0xFFFF
                            txbusy_q              <= '1';
                            -- Try to send DATA PID byte
                            if txready_s = '1' then
                                utmi_dout_q       <= data_pid_byte;
                                utmi_tvalid_q     <= '1';
                                tx_state          <= TX_DATA_PAYLOAD;                 -- move directly; payload next
                            else
                                tx_state          <= TX_DATA_PID;
                            end if;

                        else
                            -- stay idle
                            null;
                        end if;

                    when TX_HS_SEND =>
                        -- keep trying to present the handshake byte
                        if txready_s = '1' then
                            utmi_dout_q           <= hs_pid_byte;
                            utmi_tvalid_q         <= '1';
                            tx_state              <= TX_HS_WAITACC;
                        end if;

                    when TX_HS_WAITACC =>
                        -- After one cycle with valid=1, drop; EOP implied for handshake
                        utmi_tvalid_q             <= '0';
                        txbusy_q                  <= '0';
                        tx_state                  <= TX_IDLE;

                    when TX_DATA_PID =>
                        -- Re-try sending the DATA PID if we couldn't before
                        if txready_s = '1' then
                            utmi_dout_q           <= data_pid_byte;
                            utmi_tvalid_q         <= '1';
                            tx_state              <= TX_DATA_PAYLOAD;
                        end if;

                    when TX_DATA_PAYLOAD =>
                        -- Accept payload bytes from core when ready/valid handshake matches.
                        tx_tready_q               <= txready_s;                       -- we can accept when PHY can take a byte
                        if (tx_tvalid_i = '1' and txready_s = '1') then
                            -- Present payload to PHY
                            utmi_dout_q           <= tx_tdata_i;
                            utmi_tvalid_q         <= '1';

                            -- Update CRC16 over data bytes only
                            next_crc              := crc16_next(crc16_reg, tx_tdata_i);
                            crc16_reg             <= next_crc;

                            if tx_tlast_i = '1' then
                                -- Payload done: send two CRC bytes (LSB then MSB)
                                crc16_final       <= not next_crc;                    -- USB appends bitwise inverted CRC
                                tx_state          <= TX_DATA_CRC0;
                            end if;
                        end if;

                    when TX_DATA_CRC0 =>
                        if txready_s = '1' then
                            utmi_dout_q           <= crc16_final(7 downto 0);         -- LSB first on wire
                            utmi_tvalid_q         <= '1';
                            tx_state              <= TX_DATA_CRC1;
                        end if;

                    when TX_DATA_CRC1 =>
                        if txready_s = '1' then
                            utmi_dout_q           <= crc16_final(15 downto 8);        -- MSB
                            utmi_tvalid_q         <= '1';
                            tx_state              <= TX_DATA_WAITACC;
                        end if;

                    when TX_DATA_WAITACC =>
                        -- After last crc byte accepted (1-cycle valid), end packet
                        utmi_tvalid_q             <= '0';
                        txbusy_q                  <= '0';
                        tx_state                  <= TX_IDLE;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;
