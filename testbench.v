module i2c_tb();
    parameter CLK_FREQ = 50_000_000;
    parameter I2C_FREQ = 100_000;
    parameter SLAVE_ADDR = 7'h42;

    reg clk, rst, start, rw;
    reg [7:0] tx_data;
    wire busy, done, ack_error;
    wire [7:0] rx_data, slave_rx_data;

    i2c_top #(.CLK_FREQ(CLK_FREQ), .I2C_FREQ(I2C_FREQ), .SLAVE_ADDR(SLAVE_ADDR)) 
            dut (.clk(clk), .rst(rst), .start(start), .busy(busy), .done(done), .ack_error(ack_error), .rw(rw),
            .tx_data(tx_data), .rx_data(rx_data), .slave_rx_data(slave_rx_data));

    initial begin
        $dumpfile("i2c.vcd"); 
        $dumpvars(0, i2c_tb);   
    end

    initial begin
        clk = 0;
        forever #10 clk = ~clk; 
    end

task reset(); begin
    rst = 1;
    start = 0;
    rw = 0;
    tx_data = 0;

    #200;
    rst = 0;
    #200;
end
endtask

task write_byte(input [7:0] data);
begin
    @(posedge clk);
    tx_data <= data;
    rw      <= 0;
    start   <= 1;

    @(posedge clk);
    start   <= 0;

    @(posedge busy);
    @(posedge done);

    $display("Write success DATA=%h", data);

    @(posedge clk);
end
endtask

task read_byte(input [7:0] expected); begin
    @(negedge clk);
    rw = 1;
    start = 1;
    #20;

    start = 0;
    wait(busy);
    wait(done);

    if(ack_error)
        $display("Read Failed");
    else if(rx_data != expected)
        $display("READ ERROR RX=%h EXPECTED=%h", rx_data,expected);
    else
        $display("READ SUCCESS DATA=%h",rx_data);
    #200;
end

endtask

initial begin
reset();
$display("I2C TEST");
// Test 1
// Write A5
write_byte(8'hA5);

// Test 2
// Write different values
write_byte(8'h00);
write_byte(8'hFF);
write_byte(8'h55);
write_byte(8'hAA);

// Test 3
// Read default slave value
read_byte(8'hA5);

// Test 4
// random values
repeat(10) begin
    write_byte($random);
end
$display("All tests done");

#1000;

$stop;
end

always @(posedge done)begin
    $display(
    "Time=%0t Done Busy=%b ACK_Error=%b Rx=%h Slave_Rx=%h", $time, busy, ack_error, rx_data, slave_rx_data );
end

endmodule

