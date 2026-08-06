module i2c_clk_div (clk, rst, scl);
parameter CLK_FREQ = 50_000_000;
parameter I2C_FREQ = 100_000;
localparam DIVIDER = CLK_FREQ / (2*I2C_FREQ);

input clk;
input rst;
output reg scl;
reg [$clog2(DIVIDER)-1:0] count;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        count <= 0;
        scl   <= 1'b1;
    end
    else begin
        if (count == DIVIDER-1) begin
            count <= 0;
            scl   <= ~scl;
        end
        else begin
            count <= count + 1'b1;
        end
    end
end

endmodule