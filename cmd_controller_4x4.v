module cmd_controller_4x4 (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [7:0]  rx_byte,
    input  wire        rx_valid,

    // writes to activation SRAM
    output reg         act_wr_pulse,
    output reg  [1:0]  act_wr_row,
    output reg  [1:0]  act_wr_col,
    output reg  [7:0]  act_wr_data,

    // writes to weight SRAM
    output reg         wgt_wr_pulse,
    output reg  [1:0]  wgt_wr_row,
    output reg  [1:0]  wgt_wr_col,
    output reg  [7:0]  wgt_wr_data,

    // writes to bias (24-bit)
    output reg         bias_wr_pulse,
    output reg  [1:0]  bias_col,
    output reg  [23:0] bias_data,

    // control pulses
    output reg         start_compute_pulse,
    output reg         start_output_pulse
);
    localparam OP_ACT   = 8'hA0;
    localparam OP_WGT   = 8'hB0;
    localparam OP_BIAS  = 8'hC0;
    localparam OP_COMP  = 8'hD0;
    localparam OP_OUT   = 8'hE0;

    localparam S_IDLE    = 4'd0;

    localparam S_A_ROW   = 4'd1;
    localparam S_A_COL   = 4'd2;
    localparam S_A_DATA  = 4'd3;

    localparam S_W_ROW   = 4'd4;
    localparam S_W_COL   = 4'd5;
    localparam S_W_DATA  = 4'd6;

    localparam S_B_COL   = 4'd7;
    localparam S_B_D2    = 4'd8;
    localparam S_B_D1    = 4'd9;
    localparam S_B_D0    = 4'd10;

    reg [3:0] st;
    reg [7:0] op;
    reg [1:0] tmp_row, tmp_col;
    reg [7:0] tmp_data;
    reg [7:0] b2, b1, b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            st <= S_IDLE;
            op <= 8'd0;

            act_wr_pulse <= 1'b0;
            wgt_wr_pulse <= 1'b0;
            bias_wr_pulse <= 1'b0;
            start_compute_pulse <= 1'b0;
            start_output_pulse  <= 1'b0;

            act_wr_row <= 2'd0; act_wr_col <= 2'd0; act_wr_data <= 8'd0;
            wgt_wr_row <= 2'd0; wgt_wr_col <= 2'd0; wgt_wr_data <= 8'd0;

            bias_col <= 2'd0; bias_data <= 24'd0;

            tmp_row <= 0; tmp_col <= 0; tmp_data <= 0;
            b2 <= 0; b1 <= 0; b0 <= 0;
        end else begin
            // one-cycle pulses default low
            act_wr_pulse <= 1'b0;
            wgt_wr_pulse <= 1'b0;
            bias_wr_pulse <= 1'b0;
            start_compute_pulse <= 1'b0;
            start_output_pulse  <= 1'b0;

            if (rx_valid) begin
                case (st)
                    S_IDLE: begin
                        op <= rx_byte;
                        if (rx_byte == OP_ACT) st <= S_A_ROW;
                        else if (rx_byte == OP_WGT) st <= S_W_ROW;
                        else if (rx_byte == OP_BIAS) st <= S_B_COL;
                        else if (rx_byte == OP_COMP) begin
                            start_compute_pulse <= 1'b1;
                            st <= S_IDLE;
                        end else if (rx_byte == OP_OUT) begin
                            start_output_pulse <= 1'b1;
                            st <= S_IDLE;
                        end else begin
                            st <= S_IDLE; // ignore unknown
                        end
                    end

                    // ACT: row, col, data
                    S_A_ROW: begin
                        tmp_row <= rx_byte[1:0];
                        st <= S_A_COL;
                    end
                    S_A_COL: begin
                        tmp_col <= rx_byte[1:0];
                        st <= S_A_DATA;
                    end
                    S_A_DATA: begin
                        tmp_data <= rx_byte;

                        act_wr_row  <= tmp_row;
                        act_wr_col  <= tmp_col;
                        act_wr_data <= rx_byte;
                        act_wr_pulse <= 1'b1;

                        st <= S_IDLE;
                    end

                    // WGT: row, col, data
                    S_W_ROW: begin
                        tmp_row <= rx_byte[1:0];
                        st <= S_W_COL;
                    end
                    S_W_COL: begin
                        tmp_col <= rx_byte[1:0];
                        st <= S_W_DATA;
                    end
                    S_W_DATA: begin
                        tmp_data <= rx_byte;

                        wgt_wr_row  <= tmp_row;
                        wgt_wr_col  <= tmp_col;
                        wgt_wr_data <= rx_byte;
                        wgt_wr_pulse <= 1'b1;

                        st <= S_IDLE;
                    end

                    // BIAS: col, b2, b1, b0  (24-bit)
                    S_B_COL: begin
                        tmp_col <= rx_byte[1:0];
                        st <= S_B_D2;
                    end
                    S_B_D2: begin
                        b2 <= rx_byte;
                        st <= S_B_D1;
                    end
                    S_B_D1: begin
                        b1 <= rx_byte;
                        st <= S_B_D0;
                    end
                    S_B_D0: begin
                        b0 <= rx_byte;

                        bias_col  <= tmp_col;
                        bias_data <= {b2, b1, rx_byte}; // b2 b1 b0
                        bias_wr_pulse <= 1'b1;

                        st <= S_IDLE;
                    end

                    default: st <= S_IDLE;
                endcase
            end
        end
    end

endmodule