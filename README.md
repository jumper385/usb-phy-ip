## How to Setup Builder
This builder was tested on Ubuntu Server 24.04 LTS. 

yosys setup
```
cd ..
sudo apt-get install build-essential clang bison flex libreadline-dev gawk tcl-dev libffi-dev git graphviz xdot pkg-config python3 libboost-system-dev libboost-python-dev libboost-filesystem-dev zlib1g-dev
git clone https://github.com/YosysHQ/yosys
cd yosys
make config-gcc
make
sudo make install
```

GHDL Setup
```
cd ..
sudo apt install gnat-10
git clone https://github.com/ghdl/ghdl
cd ghdl
./configure --prefix=/usr/local
make
sudo make install
```

ghdl-yosys-plugin setup
```
cd ..
git clone https://github.com/ghdl/ghdl-yosys-plugin
cd ghdl-yosys-plugin
make
sudo cp ghdl.so /usr/local/share/yosys/plugins/ghdl.so
```

## Mixed VHDL + Verilog build

- Ensure Yosys, GHDL, and the `ghdl-yosys-plugin` are installed as above.
- Put your Verilog files under `verilog/` and VHDL files under `vhdl/`.
- The top entity remains VHDL (`vhdl/top.vhd`), but can instantiate Verilog modules by declaring matching VHDL components.

Quick run
```
yosys -s scripts/synth_mixed.ys
```

VHDL component stub example (to reference a Verilog module)
```
-- VHDL side (inside architecture declarative region)
component my_verilog_block
  port(
    clk   : in  std_logic;
    rst_n : in  std_logic;
    a     : in  std_logic_vector(7 downto 0);
    y     : out std_logic
  );
end component;

-- later, instantiate normally
u_blk: my_verilog_block
  port map(
    clk => clock_hf,
    rst_n => rst_n,
    a => utmi_dout,
    y => led
  );
```

Matching Verilog module
```
// verilog/my_verilog_block.v
module my_verilog_block(
  input  wire        clk,
  input  wire        rst_n,
  input  wire [7:0]  a,
  output wire        y
);
  assign y = ^a & rst_n; // simple example
endmodule
```

Notes
- Names and port directions/types must match between the VHDL component and the Verilog module (bit widths, signedness). Use std_logic/std_logic_vector for compatibility.
- Yosys reads Verilog with `read_verilog` and VHDL through the GHDL plugin, then merges the hierarchy. See `scripts/synth_mixed.ys`.
- If you use SystemVerilog, the script already passes `-sv` to `read_verilog`.
- Keep the top as VHDL or switch to a Verilog top if preferred—adjust `-top` accordingly.
