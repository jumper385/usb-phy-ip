## USB PHY IP — Mixed VHDL + Verilog Template

This repo builds a mixed-language USB PHY (VHDL top, Verilog blocks) for a Lattice iCE40 UP5K (`--package sg48`) target. It uses Yosys + GHDL + the ghdl-yosys plugin, then routes with nextpnr-ice40 and packs with IceStorm.

If you're turning this into a template, see the "Customize / Template Use" section.

## Quick Start

Run the provided synthesis/place/route script. It produces `top.json`, `top.asc`, and `top.bin` in the repo root.

```
yosys -s scripts/synth.ys
```

To program an iCE40 board using Iceprog (example):

```
iceprog top.bin
```

Adjust for your programmer/board as needed (e.g., `iceprog -S` for SPI flash, or vendor-specific tools).

## Prerequisites

Install the tooling on Ubuntu 24.04 LTS (tested):

- Yosys
- GHDL
- ghdl-yosys-plugin
- nextpnr-ice40
- IceStorm tools (`icepack`, `iceprog`)

### Option A: Use distro packages (simplest)

Package names vary. On Ubuntu/Debian, try:

```
sudo apt update
sudo apt install yosys ghdl nextpnr nextpnr-ice40 icestorm
```

If your `yosys` cannot find the GHDL plugin, you may also need the distro package for it (name varies, e.g., `ghdl-yosys-plugin` or `yosys-plugin-ghdl`).

### Option B: Build from source (original steps)

Yosys:
```
cd ..
sudo apt-get install build-essential clang bison flex libreadline-dev gawk tcl-dev libffi-dev git graphviz xdot pkg-config python3 libboost-system-dev libboost-python-dev libboost-filesystem-dev zlib1g-dev
git clone https://github.com/YosysHQ/yosys
cd yosys
make config-gcc
make
sudo make install
```

GHDL:
```
cd ..
sudo apt install gnat-10
git clone https://github.com/ghdl/ghdl
cd ghdl
./configure --prefix=/usr/local
make
sudo make install
```

ghdl-yosys-plugin:
```
cd ..
git clone https://github.com/ghdl/ghdl-yosys-plugin
cd ghdl-yosys-plugin
make
sudo cp ghdl.so /usr/local/share/yosys/plugins/ghdl.so
```

Note: If your plugin installs elsewhere, either adjust `scripts/synth.ys` to `plugin -i ghdl` (preferred when in default search path) or point to its full path.

## Repo Layout

- `vhdl/` — VHDL sources; top entity is `vhdl/top.vhd` (name: `top`).
- `verilog/` — Verilog sources for the USB PHY blocks.
- `scripts/synth.ys` — Yosys + nextpnr flow; outputs `top.json`, `top.asc`, `top.bin`.
- `io.pcf` — Pin constraints for nextpnr-ice40. Update to match your board.
- `top.json`, `top.asc`, `top.bin` — Build artifacts (created by the script).

## Customize / Template Use

Common changes when using this as a template:

- Change device/package: edit the nextpnr line in `scripts/synth.ys`.
  - Example: `nextpnr-ice40 --up5k --package sg48` → choose `--hx8k`, `--lp8k`, or the right package for your board.
- Update pinout: edit `io.pcf` to match your board's pins and I/O standards.
- Change top name: modify `vhdl/top.vhd` entity name and update `-top` in `scripts/synth.ys` (`synth_ice40 -top <name>` and the `ghdl ... -e <name>` line).
- Add RTL: place additional VHDL files under `vhdl/` and Verilog under `verilog/`, then list them in `scripts/synth.ys` (`read_verilog ...` and GHDL source list).
- Prefer relative plugin load: if your system can find the plugin, change the first line to `plugin -i ghdl` to avoid hardcoding a path.

## Mixed-Language Notes

- Keep the top in VHDL (default), and instantiate Verilog via VHDL components.
- Ensure port names, directions, and bit widths match between the VHDL component and the Verilog module.
- Yosys reads Verilog with `read_verilog` and VHDL through the GHDL plugin, then merges the hierarchy per `scripts/synth.ys`.

VHDL component stub example (referencing a Verilog module):
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
    clk   => clock_hf,
    rst_n => rst_n,
    a     => utmi_dout,
    y     => led
  );
```

Matching Verilog module:
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

## Build Artifacts

- `top.json`: Technology-mapped netlist for nextpnr.
- `top.asc`: Placed-and-routed ASCII bitstream.
- `top.bin`: Final binary for programming (from `icepack`).

## Simulation
You can simulate VHDL IP with GHDL. To do this, you first need a manifest file that lists all the VHDL files needed to run the testbench. If you are using the `-fsynopsys` flag with GHDL, you will also need to order the files from lowest level of hierarchy to highest level of hierarchy.

```
vhdl/usb_tx_phy.vhdl vhdl/usb_rx_phy.vhdl vhdl/usb_phy.vhdl vhdl/usb_phy_tb.vhdl
```

You can now run the `run_test.sh` script to run the testbench. The script takes three arguments: the path to the manifest file, the name of the top-level testbench entity, and an optional simulation time with units (e.g., `100us`, `1ms`, etc.). If no time is provided, it defaults to `10us`.
```
./run_test.sh usb_phy.tb_manifest usb_phy_tb 100us
```

> ![IMPORTANT]
> For the testbench to work correctly, you will need to order your file declarations properly - the files **MUST** be ordered from lowest level of hierarchy to highest level of hierarchy. The provided manifest file is already ordered correctly. 
> This seems to be specific to when using the `-fsynopsys` flag with GHDL. Without this flag, GHDL seems to be able to sort the files itself and is able to infer more information from the imports.

After running the script, you will be left with a `.ghw` file (GHDL waveform). You can view the `.ghw` file with `gtkwave` or equivalent. the `.ghw` file was selected because you can peer into the internal signals of the instantiated VHDL components, whereas a `.vcd` file will only show the top-level signals.

## Troubleshooting

- GHDL plugin not found: change the first line in `scripts/synth.ys` to `plugin -i ghdl` if the plugin is in Yosys' default search path. Otherwise point to its actual `.so`.
- Wrong device/package: nextpnr will error. Edit the `nextpnr-ice40` flags to match your target.
- Pin mismatch: nextpnr will report IO constraint errors. Fix `io.pcf`.
- Mixed-language elaboration errors: verify component/module port compatibility and that all sources are listed in `scripts/synth.ys`.

