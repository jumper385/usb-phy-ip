library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity usb_fifo is
    Port ( 
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        
        -- Write interface (from host RX)
        wr_en : in STD_LOGIC;
        din : in STD_LOGIC_VECTOR(7 downto 0);
        fifo_full : out STD_LOGIC;
        
        -- Read interface (to device TX)
        rd_en : in STD_LOGIC;
        dout : out STD_LOGIC_VECTOR(7 downto 0);
        fifo_empty : out STD_LOGIC;
        data_count : out STD_LOGIC_VECTOR(6 downto 0)  -- 0-64 count
    );
end usb_fifo;

architecture behavioral of usb_fifo is
    type fifo_memory is array(0 to 63) of STD_LOGIC_VECTOR(7 downto 0);
    signal memory : fifo_memory;
    
    signal wr_ptr : integer range 0 to 63 := 0;
    signal rd_ptr : integer range 0 to 63 := 0;
    signal count : integer range 0 to 64 := 0;
    
    signal empty_flag : STD_LOGIC;
    signal full_flag : STD_LOGIC;
    
begin
    -- FIFO control signals
    empty_flag <= '1' when count = 0 else '0';
    full_flag <= '1' when count = 64 else '0';
    
    fifo_empty <= empty_flag;
    fifo_full <= full_flag;
    data_count <= std_logic_vector(to_unsigned(count, 7));
    
    -- FIFO write process
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                wr_ptr <= 0;
                rd_ptr <= 0;
                count <= 0;
            else
                -- Write operation
                if wr_en = '1' and full_flag = '0' then
                    memory(wr_ptr) <= din;
                    if wr_ptr = 63 then
                        wr_ptr <= 0;
                    else
                        wr_ptr <= wr_ptr + 1;
                    end if;
                end if;
                
                -- Read operation
                if rd_en = '1' and empty_flag = '0' then
                    dout <= memory(rd_ptr);
                    if rd_ptr = 63 then
                        rd_ptr <= 0;
                    else
                        rd_ptr <= rd_ptr + 1;
                    end if;
                end if;
                
                -- Update count
                if wr_en = '1' and rd_en = '0' and full_flag = '0' then
                    count <= count + 1;
                elsif rd_en = '1' and wr_en = '0' and empty_flag = '0' then
                    count <= count - 1;
                end if;
            end if;
        end if;
    end process;
    
end behavioral;
