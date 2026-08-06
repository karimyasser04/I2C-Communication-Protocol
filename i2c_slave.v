module i2c_slave (clk, rst, scl_in, sda_in, sda_drive_low, rx_data);
parameter SLAVE_ADDR = 7'h42;

input clk, rst, scl_in, sda_in;
output reg sda_drive_low;

output reg [7:0] rx_data;

reg [7:0] shift_reg, tx_reg;
reg [3:0] bit_cnt;
reg ack_driven, ack_wait, scl_d;

localparam IDLE = 4'd0;
localparam RECV_ADDR = 4'd1;
localparam ADDR_ACK = 4'd2;
localparam WRITE_DATA = 4'd3;
localparam READ_DATA = 4'd4;
localparam DATA_ACK = 4'd5;
localparam WAIT_STOP = 4'd6;
localparam READ_ACK = 4'd7;

reg [4:0] state;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        scl_d <= 1'b1;
    end
    else begin
        scl_d <= scl_in;
    end
end

wire scl_rise = ~scl_d & scl_in;
wire scl_fall = scl_d & ~scl_in;

reg sda_prev;
always @(posedge clk or posedge rst)
begin
    if(rst)
        sda_prev <= 1'b1;
    else
        sda_prev <= sda_in;
end

wire start_detect = (sda_prev == 1'b1) && (sda_in == 1'b0) && (scl_in == 1'b1);
wire stop_detect = (sda_prev == 1'b0) && (sda_in == 1'b1) && (scl_in == 1'b1);

reg rw;
reg [7:0] data_reg;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        sda_drive_low <= 1'b0;
        shift_reg <= 8'd0;
        data_reg <= 8'd0;
        rx_data <= 8'd0;
        bit_cnt <= 4'd0;
        rw <= 1'b0;
        tx_reg <= 8'hA5;
        ack_driven <= 1'b0;
        ack_wait <= 1'b0;
    end
    else begin

        case (state)

            IDLE: begin
                sda_drive_low <= 1'b0;

                if (start_detect) begin
                    bit_cnt <= 4'd7;
                    shift_reg <= 8'd0;
                    state <= RECV_ADDR;
                end
            end

            RECV_ADDR: begin
                if (scl_rise) begin
                    $display("SLAVE RECV_ADDR bit=%0d SDA=%b", bit_cnt, sda_in);
                    shift_reg[bit_cnt] <= sda_in;
                    if (bit_cnt == 0) begin
                    $display("SLAVE RECV_ADDR bit=%0d SDA=%b", bit_cnt, sda_in);
                    rw <= sda_in;
                    state <= ADDR_ACK;
                    ack_driven <= 1'b0;
                    end
                    else begin
                    bit_cnt <= bit_cnt - 1'b1;
                    end
                end
end

            ADDR_ACK: begin
                if (shift_reg[7:1] != SLAVE_ADDR) begin
                    sda_drive_low <= 1'b0;
                    if (stop_detect)
                        state <= IDLE;
                end
                else begin
                    if (scl_fall) begin
                        sda_drive_low <= 1'b1;
                        ack_driven <= 1'b1;
                    end
                    if (scl_rise && ack_driven) begin
                        sda_drive_low <= 1'b0;
                        bit_cnt <= 4'd7;
                        if (rw)
                            begin
                                shift_reg <= tx_reg;
                                state <= READ_DATA;
                            end
                        else
                            state <= WRITE_DATA;
                    end
                end
end

            WRITE_DATA: begin
                if (scl_rise) begin
                    shift_reg[bit_cnt] <= sda_in;

                    if (bit_cnt == 0)
                        state <= DATA_ACK;
                    else
                        bit_cnt <= bit_cnt - 1'b1;
                end
            end

            DATA_ACK: begin
                if (scl_fall)
                    sda_drive_low <= 1'b1;

                if (scl_rise) begin
                    sda_drive_low <= 1'b0;

                    data_reg <= shift_reg;
                    rx_data <= shift_reg;

                    state <= WAIT_STOP;
                end
            end

            WAIT_STOP: begin
                sda_drive_low <= 1'b0;
                if (stop_detect)
                    state <= IDLE;
                if (start_detect)
                    state <= RECV_ADDR;
end

            READ_DATA: begin
                if (scl_fall) begin
                sda_drive_low <= ~shift_reg[7];
                shift_reg <= {shift_reg[6:0], 1'b0};
                    if (bit_cnt == 0) begin
                    state <= READ_ACK;
                    ack_wait <= 1'b0;
                end
                else begin
                bit_cnt <= bit_cnt - 1'b1;
            end
        end
end

            READ_ACK: begin
                if (scl_fall) begin
                    sda_drive_low <= 1'b0;
                    ack_wait <= 1'b1;
                end
                if (scl_rise && ack_wait) begin
                    if (sda_in == 1'b0) begin
                        shift_reg <= data_reg;
                        bit_cnt <= 4'd7;
                        state <= READ_DATA;
                    end
                    else begin
                        state <= WAIT_STOP;
                    end
                end
end

            default: state <= IDLE;
        endcase
    end
end

endmodule
