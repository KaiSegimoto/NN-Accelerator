module spi_nibble_slave (
    input  wire clk,
    input  wire rst_n,
    input  wire spi_sclk,
    input  wire spi_cs_n,
    input  wire spi_mosi,
    output reg  [3:0] nibble_out,
    output reg        nibble_valid
);
    reg spi_sclk_d;
    reg [1:0] bit_count;
    reg [3:0] shift_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            spi_sclk_d   <= 1'b0;
            bit_count    <= 2'd0;
            shift_reg    <= 4'd0;
            nibble_out   <= 4'd0;
            nibble_valid <= 1'b0;
        end else begin
            spi_sclk_d   <= spi_sclk;
            nibble_valid <= 1'b0;

            if (spi_cs_n) begin
                bit_count <= 2'd0;
            end else if (!spi_sclk_d && spi_sclk) begin
                shift_reg <= {shift_reg[2:0], spi_mosi};
                if (bit_count == 2'd3) begin
                    nibble_out   <= {shift_reg[2:0], spi_mosi};
                    nibble_valid <= 1'b1;
                    bit_count    <= 2'd0;
                end else begin
                    bit_count <= bit_count + 2'd1;
                end
            end
        end
    end
endmodule
