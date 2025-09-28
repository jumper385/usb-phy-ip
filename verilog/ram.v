// bram_2048x10.v
// 2048 x 10-bit true dual-port RAM (1 write, 1 read)
module bram_2048x10 (
    input  wire        wclk,
    input  wire        we,
    input  wire [10:0] waddr,   // 0..2047
    input  wire [9:0]  din,

    input  wire        rclk,
    input  wire        re,
    input  wire [10:0] raddr,
    output reg  [9:0]  dout
);
    // Yosys hint for iCE40 block RAM
    (* ram_style = "block" *)
    reg [9:0] mem [0:2047];

    // write port
    always @(posedge wclk) begin
        if (we)
            mem[waddr] <= din;
    end

    // synchronous read
    always @(posedge rclk) begin
        if (re)
            dout <= mem[raddr];
    end
endmodule
