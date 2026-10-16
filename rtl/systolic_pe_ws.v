module systolic_pe_ws #(
    parameter integer ACC_W = 4
) (
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    load_weight_en,
    input  wire                    weight_in,
    input  wire                    valid_in,
    input  wire                    a_in,
    input  wire signed [ACC_W-1:0] psum_in,
    output reg                     valid_out,
    output reg                     a_out,
    output reg  signed [ACC_W-1:0] psum_out
);
    reg weight_reg;
    wire signed [ACC_W-1:0] prod_term;

    // Bipolar 1-bit multiply:
    // equal bits => +1, different bits => -1
    assign prod_term = (a_in ^ weight_reg) ? -{{(ACC_W-1){1'b0}}, 1'b1}
                                           :  {{(ACC_W-1){1'b0}}, 1'b1};

    always @(posedge clk) begin
        if (!rst_n) begin
            weight_reg <= 1'b0;
            valid_out  <= 1'b0;
            a_out      <= 1'b0;
            psum_out   <= {ACC_W{1'b0}};
        end else begin
            if (load_weight_en)
                weight_reg <= weight_in;

            valid_out <= valid_in;
            a_out     <= a_in;

            if (valid_in)
                psum_out <= psum_in + prod_term;
            else
                psum_out <= psum_in;
        end
    end
endmodule
