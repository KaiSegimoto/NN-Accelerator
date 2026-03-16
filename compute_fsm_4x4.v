module compute_fsm_4x4 (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,    // 1-cycle pulse
    output reg         done,     // 1-cycle pulse when finished

    // Activation SRAM read ports (use your sram_4x4x8_4read)
    output reg         act_rd_en,
    output reg  [1:0]  act_row,
    input  wire [7:0]  act_c0,
    input  wire [7:0]  act_c1,
    input  wire [7:0]  act_c2,
    input  wire [7:0]  act_c3,

    // Weight SRAM read ports
    output reg         wgt_rd_en,
    output reg  [1:0]  wgt_row,
    input  wire [7:0]  wgt_c0,
    input  wire [7:0]  wgt_c1,
    input  wire [7:0]  wgt_c2,
    input  wire [7:0]  wgt_c3,

    // Bias memory (4 cols, signed 24-bit)
    input  wire signed [23:0] bias0,
    input  wire signed [23:0] bias1,
    input  wire signed [23:0] bias2,
    input  wire signed [23:0] bias3,

    // Output memory write (one row per finish i)
    output reg         out_wr_en,
    output reg  [1:0]  out_wr_row,
    output reg  [7:0]  out_wr_d0,
    output reg  [7:0]  out_wr_d1,
    output reg  [7:0]  out_wr_d2,
    output reg  [7:0]  out_wr_d3
);

    localparam ST_IDLE      = 4'd0;
    localparam ST_RD_ACT    = 4'd1;
    localparam ST_ACT_WAIT  = 4'd2;
    localparam ST_ACT_LATCH = 4'd3;
    localparam ST_RD_WGT    = 4'd4;
    localparam ST_WGT_WAIT  = 4'd5;
    localparam ST_WGT_ACC   = 4'd6;
    localparam ST_FINAL     = 4'd7;
    localparam ST_NEXTROW   = 4'd8;

    reg [3:0] st;

    reg [1:0] i_row;  // 0..3
    reg [1:0] k_idx;  // 0..3

    // latched activation row A[i][0..3]
    reg signed [7:0] a0, a1, a2, a3;

    // accumulators for 4 outputs (signed 24-bit)
    reg signed [23:0] acc0, acc1, acc2, acc3;

    // combinational pick A[i][k]
    wire signed [7:0] a_scalar =
        (k_idx == 2'd0) ? a0 :
        (k_idx == 2'd1) ? a1 :
        (k_idx == 2'd2) ? a2 : a3;

    // dot-product step combinational
    wire signed [23:0] acc0_n, acc1_n, acc2_n, acc3_n;
    dotprod_step4 u_dp (
        .a_scalar(a_scalar),
        .w0($signed(wgt_c0)), .w1($signed(wgt_c1)), .w2($signed(wgt_c2)), .w3($signed(wgt_c3)),
        .acc0_in(acc0), .acc1_in(acc1), .acc2_in(acc2), .acc3_in(acc3),
        .acc0_out(acc0_n), .acc1_out(acc1_n), .acc2_out(acc2_n), .acc3_out(acc3_n)
    );

    // activation (ReLU+quant) after bias
    wire [7:0] q0, q1, q2, q3;
    activation_unit_relu_q8 u_act0(.in_val(acc0 + bias0), .out_q8(q0));
    activation_unit_relu_q8 u_act1(.in_val(acc1 + bias1), .out_q8(q1));
    activation_unit_relu_q8 u_act2(.in_val(acc2 + bias2), .out_q8(q2));
    activation_unit_relu_q8 u_act3(.in_val(acc3 + bias3), .out_q8(q3));

    always @(posedge clk) begin
        if (!rst_n) begin
            st        <= ST_IDLE;
            done      <= 1'b0;

            act_rd_en <= 1'b0;
            act_row   <= 2'd0;
            wgt_rd_en <= 1'b0;
            wgt_row   <= 2'd0;

            out_wr_en  <= 1'b0;
            out_wr_row <= 2'd0;
            out_wr_d0  <= 8'd0;
            out_wr_d1  <= 8'd0;
            out_wr_d2  <= 8'd0;
            out_wr_d3  <= 8'd0;

            i_row <= 2'd0;
            k_idx <= 2'd0;

            a0 <= 0; a1 <= 0; a2 <= 0; a3 <= 0;
            acc0 <= 0; acc1 <= 0; acc2 <= 0; acc3 <= 0;
        end else begin
            done      <= 1'b0;
            out_wr_en <= 1'b0;

            // default deassert reads unless state sets them
            act_rd_en <= 1'b0;
            wgt_rd_en <= 1'b0;

            case (st)
                ST_IDLE: begin
                    if (start) begin
                        i_row <= 2'd0;
                        st    <= ST_RD_ACT;
                    end
                end

                // issue activation read for row i
                ST_RD_ACT: begin
                    act_row   <= i_row;
                    act_rd_en <= 1'b1;
                    st        <= ST_ACT_WAIT;
                end

                // wait for registered SRAM read data to update
                ST_ACT_WAIT: begin
                    st <= ST_ACT_LATCH;
                end

                ST_ACT_LATCH: begin
                    // latch A row
                    a0 <= $signed(act_c0);
                    a1 <= $signed(act_c1);
                    a2 <= $signed(act_c2);
                    a3 <= $signed(act_c3);

                    // clear accumulators
                    acc0 <= 24'sd0;
                    acc1 <= 24'sd0;
                    acc2 <= 24'sd0;
                    acc3 <= 24'sd0;

                    k_idx <= 2'd0;
                    st    <= ST_RD_WGT;
                end

                // issue weight read for row k
                ST_RD_WGT: begin
                    wgt_row   <= k_idx;
                    wgt_rd_en <= 1'b1;
                    st        <= ST_WGT_WAIT;
                end

                // wait for registered SRAM read data to update
                ST_WGT_WAIT: begin
                    st <= ST_WGT_ACC;
                end

                ST_WGT_ACC: begin
                    // use wgt_c* from this cycle (registered)
                    acc0 <= acc0_n;
                    acc1 <= acc1_n;
                    acc2 <= acc2_n;
                    acc3 <= acc3_n;

                    if (k_idx == 2'd3) begin
                        st <= ST_FINAL;
                    end else begin
                        k_idx <= k_idx + 2'd1;
                        st    <= ST_RD_WGT;
                    end
                end

                // add bias + relu+quant; write output memory row i
                ST_FINAL: begin
                    out_wr_en  <= 1'b1;
                    out_wr_row <= i_row;
                    out_wr_d0  <= q0;
                    out_wr_d1  <= q1;
                    out_wr_d2  <= q2;
                    out_wr_d3  <= q3;
                    st         <= ST_NEXTROW;
                end

                ST_NEXTROW: begin
                    if (i_row == 2'd3) begin
                        done <= 1'b1;
                        st   <= ST_IDLE;
                    end else begin
                        i_row <= i_row + 2'd1;
                        st    <= ST_RD_ACT;
                    end
                end

                default: st <= ST_IDLE;
            endcase
        end
    end

endmodule
