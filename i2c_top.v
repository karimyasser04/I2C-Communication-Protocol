module i2c_top (clk, rst, start, busy, done, ack_error, rw, tx_data, rx_data);

parameter CLK_FREQ = 50_000_000;
parameter I2C_FREQ = 100_000;
parameter SLAVE_ADDR = 7'h42;

input clk, rst, start, rw;
input [7:0] tx_data;

output busy, done, ack_error;
output [7:0] rx_data;

wire scl, sda;

i2c_master #(.CLK_FREQ(CLK_FREQ), .I2C_FREQ(I2C_FREQ), .SLAVE_ADDR(SLAVE_ADDR)) master (
    .clk(clk),
    .rst(rst),
    .start(start),
    .scl(scl),
    .sda(sda),
    .busy(busy),
    .done(done),
    .ack_error(ack_error),
    .rw(rw),
    .tx_data(tx_data),
    .rx_data(rx_data)
);

i2c_slave #(.SLAVE_ADDR(SLAVE_ADDR)) slave (
    .clk(clk),
    .rst(rst),
    .scl(scl),
    .sda(sda),
    .rx_data()
);

endmodule
