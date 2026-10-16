module systolic_array_ws_4x4 #(
    parameter integer ACC_W = 4
) (
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    load_weight_en,
    input  wire [1:0]              load_weight_row_idx,
    input  wire [3:0]              load_weight_row_data,
    input  wire                    start_vector,
    input  wire [3:0]              vector_in,
    output reg                     out_valid,
    output reg  [1:0]              out_col_idx,
    output reg  signed [ACC_W-1:0] out_data,
    output reg                     busy,
    output reg                     done
);
    reg [3:0] inject_valid_r;
    reg [3:0] inject_vec;
    reg        active;
    reg [2:0]  cycle_ctr;

    wire [15:0] valid_pipe;
    wire [15:0] act_pipe;
    wire [(16*ACC_W)-1:0] psum_pipe;

    genvar r, c;
    generate
        for (r = 0; r < 4; r = r + 1) begin : GEN_ROWS
            for (c = 0; c < 4; c = c + 1) begin : GEN_COLS
                wire pe_valid_in;
                wire pe_a_in;
                wire signed [ACC_W-1:0] pe_psum_in;
                wire pe_weight_in;
                wire pe_load_weight_en;

                assign pe_load_weight_en = load_weight_en && (load_weight_row_idx == r[1:0]);
                assign pe_weight_in      = load_weight_row_data[c];

                if (c == 0) begin : GEN_LEFT_EDGE
                    assign pe_valid_in = inject_valid_r[r];
                    assign pe_a_in     = inject_vec[r];
                end else begin : GEN_INTERNAL_ACT
                    assign pe_valid_in = valid_pipe[((r*4)+c)-1];
                    assign pe_a_in     = act_pipe[((r*4)+c)-1];
                end

                if (r == 0) begin : GEN_TOP_EDGE
                    assign pe_psum_in = {ACC_W{1'b0}};
                end else begin : GEN_INTERNAL_PSUM
                    assign pe_psum_in = psum_pipe[((((r-1)*4)+c)*ACC_W)+(ACC_W-1):((((r-1)*4)+c)*ACC_W)];
                end

                systolic_pe_ws #(.ACC_W(ACC_W)) u_pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    .load_weight_en(pe_load_weight_en),
                    .weight_in(pe_weight_in),
                    .valid_in(pe_valid_in),
                    .a_in(pe_a_in),
                    .psum_in(pe_psum_in),
                    .valid_out(valid_pipe[(r*4)+c]),
                    .a_out(act_pipe[(r*4)+c]),
                    .psum_out(psum_pipe[(((r*4)+c)*ACC_W)+(ACC_W-1):(((r*4)+c)*ACC_W)])
                );
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (!rst_n) begin
            inject_vec     <= 16'd0;
            inject_valid_r <= 4'd0;
            active         <= 1'b0;
            cycle_ctr      <= 3'd0;
            out_valid      <= 1'b0;
            out_col_idx    <= 2'd0;
            out_data       <= {ACC_W{1'b0}};
            busy           <= 1'b0;
            done           <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            done      <= 1'b0;

            if (start_vector && !active) begin
                inject_vec     <= vector_in;
                inject_valid_r <= 4'b0001;
                active         <= 1'b1;
                busy           <= 1'b1;
                cycle_ctr      <= 3'd0;
            end else if (active) begin
                inject_valid_r <= {inject_valid_r[2:0], 1'b0};

                if (cycle_ctr >= 4) begin
                    out_valid   <= 1'b1;
                    out_col_idx <= cycle_ctr - 4;
                    case (cycle_ctr - 4)
                        2'd0: out_data <= psum_pipe[(12*ACC_W)+(ACC_W-1):(12*ACC_W)];
                        2'd1: out_data <= psum_pipe[(13*ACC_W)+(ACC_W-1):(13*ACC_W)];
                        2'd2: out_data <= psum_pipe[(14*ACC_W)+(ACC_W-1):(14*ACC_W)];
                        default: out_data <= psum_pipe[(15*ACC_W)+(ACC_W-1):(15*ACC_W)];
                    endcase
                end

                if (cycle_ctr == 7) begin
                    active         <= 1'b0;
                    busy           <= 1'b0;
                    done           <= 1'b1;
                    cycle_ctr      <= 3'd0;
                    inject_valid_r <= 4'd0;
                end else begin
                    cycle_ctr <= cycle_ctr + 3'd1;
                end
            end
        end
    end
endmodule
