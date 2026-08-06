module i2c_master (clk, rst, start, scl_in, scl_drive_low, sda_drive_low, sda_in, busy, done, ack_error, rw, tx_data, rx_data);
parameter CLK_FREQ = 50_000_000;
parameter I2C_FREQ = 100_000;
parameter SLAVE_ADDR = 7'h42;

input clk, rst, start, rw, scl_in, sda_in;

output reg scl_drive_low, sda_drive_low, busy, done, ack_error;

input [7:0] tx_data;
output reg [7:0] rx_data;
reg [7:0] shift_reg;
reg [3:0] bit_cnt;
reg ack_released;

//Clock Divider
wire scl_int;
i2c_clk_div #(.CLK_FREQ(CLK_FREQ), .I2C_FREQ(I2C_FREQ)) clk_div (.clk(clk), .rst(rst), .scl(scl_int));

reg scl_d;
always @(posedge clk or posedge rst) begin
    if (rst)
        scl_d <= 1'b1;
    else
        scl_d <= scl_in;
end

wire scl_rise = ~scl_d & scl_in;
wire scl_fall = scl_d & ~scl_in;

//FSM 
localparam IDLE = 4'd0;
localparam START_ST = 4'd1;
localparam START_HOLD = 4'd2;
localparam SEND_ADDR = 4'd3;
localparam ADDR_ACK = 4'd4;
localparam WRITE_DATA = 4'd5;
localparam READ_DATA = 4'd6;
localparam DATA_ACK = 4'd7;
localparam STOP_LOW = 4'd8;
localparam STOP_HIGH = 4'd9;
localparam DONE_ST = 4'd10;
localparam MASTER_ACK = 4'd11;

reg [4:0] state;

always @(posedge clk or posedge rst) begin
    if(rst)
        scl_drive_low <= 1'b0;
    else begin
        if(busy)
            scl_drive_low <= ~scl_int;
        else
            scl_drive_low <= 1'b0;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        busy <= 1'b0;
        done <= 1'b0;
        sda_drive_low <= 1'b0;
        ack_error <= 1'b0;
        rx_data <= 8'd0;
        shift_reg <= 8'd0;
        bit_cnt <= 4'd0;
        ack_released <= 1'b0;
    end
    else begin
    done <= 1'b0;

    case (state)
            IDLE: begin
                busy <= 1'b0;
                sda_drive_low <= 1'b0;

                if (start) begin
                    ack_error <= 1'b0;
                    busy <= 1'b1;
                    state <= START_ST;
                end
end

            START_ST: begin
                if (scl_in) begin
                    sda_drive_low <= 1'b1;
                    shift_reg <= {SLAVE_ADDR, rw};
                    bit_cnt <= 4'd7;
                    state <= SEND_ADDR;
                end
end

            STOP_LOW: begin
                if (scl_fall) begin
                    sda_drive_low <= 1'b1;
                    state <= STOP_HIGH;
                end
end

            STOP_HIGH: begin
                if (scl_rise) begin
                    sda_drive_low <= 1'b0;
                    state <= DONE_ST;
                end
end

            DONE_ST: begin
                busy <= 1'b0;
                done <= 1'b1;
                state <= IDLE;
end

            SEND_ADDR: begin
                if (scl_fall) begin
                    sda_drive_low <= ~shift_reg[7];
                    shift_reg <= {shift_reg[6:0], 1'b0};
                    if (bit_cnt == 0) begin
                        state <= ADDR_ACK;
                        ack_released <= 1'b0;
                    end
                    else
                        bit_cnt <= bit_cnt - 1'b1;
                end
end

            ADDR_ACK: begin
                if (scl_fall) begin
                sda_drive_low <= 1'b0;
                ack_released <= 1'b1;
            end

                if (scl_rise && ack_released) begin
                    if (sda_in == 1'b0) begin
                    //ACK
                    if (rw == 1'b0) begin
                        shift_reg <= tx_data;
                        bit_cnt <= 4'd7;
                        state <= WRITE_DATA;
                    end
                    else begin
                        bit_cnt <= 4'd7;
                        rx_data <= 8'd0;
                        state <= READ_DATA;
                    end
                end
                    else begin
                    ack_error <= 1'b1;
                    state <= STOP_LOW;
                end
            end
end

            WRITE_DATA: begin
                if (scl_fall) begin
                    sda_drive_low <= ~shift_reg[7];
                    shift_reg <= {shift_reg[6:0], 1'b0};
                    if (bit_cnt == 0) begin
                        state <= DATA_ACK;
                        ack_released <= 1'b0;
                    end
                    else
                        bit_cnt <= bit_cnt - 1'b1;
                end
end

            DATA_ACK: begin
                if (scl_fall) begin
                sda_drive_low <= 1'b0;
                ack_released <= 1'b1;
                end

                if (scl_rise && ack_released) begin
                    if (sda_in == 1'b0)
                    state <= STOP_LOW;
                    else begin
                    ack_error <= 1'b1;
                    state <= STOP_LOW;
                end
            end
end

            READ_DATA: begin
                if(scl_rise) begin
                    rx_data[bit_cnt] <= sda_in;
                    if(bit_cnt == 0) begin
                    sda_drive_low <= 1'b0;
                    state <= MASTER_ACK;
                end
                else
                bit_cnt <= bit_cnt - 1'b1;
            end
end

            MASTER_ACK: begin
                if(scl_fall)
                    sda_drive_low <= 1'b0;
                if (scl_rise) begin
                    sda_drive_low <= 1'b0;
                    state <= STOP_LOW;
                end
end

            default: state <= IDLE;
        endcase
    end
end

endmodule
