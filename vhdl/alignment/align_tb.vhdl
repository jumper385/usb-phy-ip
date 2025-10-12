-- tb_align_tx.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_align_tx is
end entity;

architecture sim of tb_align_tx is
  -- DUT ports
  signal clk_i       : std_logic := '0';
  signal rst_i       : std_logic := '0';
  signal align_en_i  : std_logic := '0';
  signal align_sig_o : std_logic;
  
  -- RX signals
  signal is_aligned_o : std_logic;

  -- Expected pattern
  constant PATTERN : std_logic_vector(7 downto 0) := x"BC"; -- 1011_1100 (MSB-first)

  -- Clock period
  constant TCLK : time := 10 ns;

  -- Helper for pretty assertions
  procedure check_equal(a, b : std_logic; msg : string) is
  begin
    assert a = b
      report msg & "  got=" & std_logic'image(a) & " expected=" & std_logic'image(b)
      severity error;
  end procedure;

begin
  ---------------------------------------------------------------------------
  -- Clock
  ---------------------------------------------------------------------------
  clk_i <= not clk_i after TCLK/2;

  ---------------------------------------------------------------------------
  -- DUT TX
  ---------------------------------------------------------------------------
  uut_tx: entity work.align_tx
    port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      align_en_i  => align_en_i,
      align_sig_o => align_sig_o
    );

  ---------------------------------------------------------------------------
  -- DUT RX
  ---------------------------------------------------------------------------
  uut_rx: entity work.align_rx
    port map (
      clk_i        => clk_i,
      rst_i        => rst_i,
      align_en_i   => align_en_i,
      align_sig_i  => align_sig_o,
      is_aligned_o => is_aligned_o
    );

  ---------------------------------------------------------------------------
  -- Stimulus + Checks
  ---------------------------------------------------------------------------
  stim: process
    variable bit_idx : integer := 0;
    variable exp_bit : std_logic;
    constant N_BYTES : integer := 4;  -- stream 4 full bytes for checking
  begin
    -- Hold reset high for a few cycles (synchronous, active-high)
    rst_i <= '1';
    align_en_i <= '0';
    for i in 0 to 2 loop
      wait until rising_edge(clk_i);
    end loop;

    -- Release reset
    rst_i <= '1';
    wait until rising_edge(clk_i);

    -- Check initial RX state
    check_equal(is_aligned_o, '0', "RX should not be aligned initially");

    -- Idle behavior: output should be '1' (default high)
    for i in 0 to 3 loop
      wait until rising_edge(clk_i);
      check_equal(align_sig_o, '1', "Idle output must be '1'");
      check_equal(is_aligned_o, '0', "RX should not detect alignment in idle");
    end loop;

    -- Enable streaming
    align_en_i <= '1';

    -- Wait for TX to start and RX to detect pattern
    wait until rising_edge(clk_i); -- state updates to START_BIT
    wait until rising_edge(clk_i); -- state updates to SEND
    
    -- Wait for pattern detection (RX needs 8 bits to detect pattern)
    for i in 0 to 15 loop
      wait until rising_edge(clk_i);
      if is_aligned_o = '1' then
        report "Pattern detected at cycle " & integer'image(i) severity note;
        exit;
      end if;
    end loop;

    -- Check N_BYTES * 10 bits (start + 8 data + stop) per frame
    for k in 0 to N_BYTES*10-1 loop
      bit_idx := k mod 10;
      if bit_idx = 0 then
        -- Start bit
        check_equal(align_sig_o, '0', "Start bit should be '0' at bit " & integer'image(k));
      elsif bit_idx >= 1 and bit_idx <= 8 then
        -- Data bits (MSB first)
        exp_bit := PATTERN(8 - bit_idx); -- MSB-first: bits 7 down to 0
        check_equal(align_sig_o, exp_bit,
          "Data bit mismatch at bit " & integer'image(k) & " (data bit " & integer'image(bit_idx-1) & ")");
      else
        -- Stop bit
        check_equal(align_sig_o, '1', "Stop bit should be '1' at bit " & integer'image(k));
      end if;
      
      -- Check RX alignment detection
      if bit_idx = 9 then -- End of frame
        check_equal(is_aligned_o, '1', "RX should detect alignment at end of frame " & integer'image(k/10));
      end if;
      
      wait until rising_edge(clk_i);
    end loop;

    -- Disable mid-stream: output should go low on the next valid cycle
    align_en_i <= '0';
    wait until rising_edge(clk_i); -- SEND->IDLE transition completes
    wait until rising_edge(clk_i); -- registered output low
    check_equal(align_sig_o, '1', "Output must return to '1' after disable");
    check_equal(is_aligned_o, '0', "RX should lose alignment when disabled");

    -- Re-enable and ensure the pattern restarts from MSB
    align_en_i <= '1';
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);
    exp_bit := PATTERN(7); -- MSB
    check_equal(align_sig_o, exp_bit, "Pattern should restart from MSB after re-enable");

    -- Wait for RX to detect pattern again
    for i in 0 to 15 loop
      wait until rising_edge(clk_i);
      if is_aligned_o = '1' then
        report "Pattern re-detected at cycle " & integer'image(i) severity note;
        exit;
      end if;
    end loop;

    -- A few more bits for sanity
    for k in 1 to 7 loop
      wait until rising_edge(clk_i);
      exp_bit := PATTERN(7 - (k mod 8));
      check_equal(align_sig_o, exp_bit, "Post-restart bit check at k=" & integer'image(k));
    end loop;

    report "TX/RX integration test completed OK" severity note;
    wait for 20 ns;
    wait;
  end process;

end architecture;