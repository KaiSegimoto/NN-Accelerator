module serial_to_parallel_8 #(
    parameter MSB_FIRST = 1  // 1: MSB first; 0: LSB first
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        ser_cs,   // CS active HIGH: 1=transfer valid window
    input  wire        ser_din,  // MOSI

    output reg  [7:0]  rx_byte,
    output reg         rx_valid
);

    reg [7:0] shift;
    reg [2:0] cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            shift    <= 8'd0;
            cnt      <= 3'd0;
            rx_byte  <= 8'd0;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0;

            if (ser_cs) begin
                if (MSB_FIRST) shift <= {shift[6:0], ser_din};
                else           shift <= {ser_din, shift[7:1]};

                cnt <= cnt + 3'd1;

                if (cnt == 3'd7) begin
                    rx_byte  <= MSB_FIRST ? {shift[6:0], ser_din}
                                          : {ser_din, shift[7:1]};
                    rx_valid <= 1'b1;
                    cnt      <= 3'd0;
                end
            end else begin
                cnt <= 3'd0; // CS无效时清计数（SPI帧间复位）
            end
        end
    end

endmodule