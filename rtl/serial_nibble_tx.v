module serial_nibble_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] nibble_in,
    input  wire       load,
    input  wire       shift_en,
    output reg        serial_out,
    output reg        busy
);
    reg [3:0] shift_reg;
    reg [1:0] bits_left;

    always @(posedge clk) begin
        if (!rst_n) begin
            shift_reg   <= 4'd0;
            bits_left   <= 2'd0;
            serial_out  <= 1'b0;
            busy        <= 1'b0;
        end else begin
            if (load) begin
                serial_out <= nibble_in[3];
                shift_reg  <= {nibble_in[2:0], 1'b0};
                bits_left  <= 2'd3;
                busy       <= 1'b1;
            end else if (shift_en && busy) begin
                serial_out <= shift_reg[3];
                shift_reg  <= {shift_reg[2:0], 1'b0};
                if (bits_left == 2'd1) begin
                    bits_left <= 2'd0;
                    busy      <= 1'b0;
                end else begin
                    bits_left <= bits_left - 2'd1;
                end
            end
        end
    end
endmodule
