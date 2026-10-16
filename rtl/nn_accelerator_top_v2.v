module nn_accelerator_top (
    input  wire clk,
    input  wire rst_n,
    input  wire spi_sclk,
    input  wire spi_cs_n,
    input  wire spi_mosi,
    input  wire load_req,
    input  wire [1:0] load_target,
    input  wire execute_req,
    input  wire output_req,
    output wire busy,
    output wire serial_out,
    output wire [3:0]  out_row_data_dbg,
    output wire [3:0]  spi_nibble_dbg,
    output wire        array_out_valid_dbg,
    output wire signed [3:0] array_out_data_dbg,
    output wire [3:0]  quantized_value_dbg
);
    localparam LOAD_INPUT  = 2'b00;
    localparam LOAD_WEIGHT = 2'b01;
    localparam LOAD_BIAS   = 2'b10;

    localparam EX_IDLE      = 4'd0;
    localparam EX_LOAD_WROW = 4'd1;
    localparam EX_START_ROW = 4'd2;
    localparam EX_WAIT_ROW  = 4'd3;
    localparam EX_ADD_BIAS  = 4'd4;
    localparam EX_FINISH    = 4'd5;

    localparam OUT_IDLE      = 3'd0;
    localparam OUT_LOAD_NIB  = 3'd1;
    localparam OUT_SHIFT_NIB = 3'd2;
    localparam OUT_NEXT_NIB  = 3'd3;
    localparam OUT_FINISH    = 3'd4;

    wire [3:0] spi_nibble;
    wire       spi_nibble_valid;

    reg        load_done_r, exec_done_r, output_done_r;
    wire       load_mode, exec_mode, output_mode;

    reg        load_active;
    reg [1:0]  load_target_latched;
    reg [4:0]  load_count;

    reg [3:0]  in_rows [0:3];
    reg [3:0]  wt_rows [0:3];
    reg signed [3:0] bias_mem [0:15];
    reg [3:0]  out_rows [0:3];

    reg        array_load_weight_en;
    reg [1:0]  array_load_weight_idx;
    reg [3:0]  array_load_weight_row;
    reg        array_start_vector;
    reg [3:0]  array_vector_in;
    wire       array_out_valid;
    wire [1:0] array_out_col_idx;
    wire signed [3:0] array_out_data;
    wire       array_busy;
    wire       array_done;

    reg [1:0]  exec_row_idx;
    reg [1:0]  wt_load_row_idx;
    reg [3:0]  ex_state;

    reg signed [3:0] raw_row_col0;
    reg signed [3:0] raw_row_col1;
    reg signed [3:0] raw_row_col2;
    reg signed [3:0] raw_row_col3;

    reg [1:0]  out_rd_row;
    reg [2:0]  out_state;
    reg [1:0]  out_row_idx;
    reg [1:0]  out_shift_count;

    reg        tx_load;
    reg        tx_shift_en;
    reg [3:0]  tx_nibble_in;
    wire       tx_busy;

    wire [3:0] out_row_data;
    wire signed [3:0] bias_col0;
    wire signed [3:0] bias_col1;
    wire signed [3:0] bias_col2;
    wire signed [3:0] bias_col3;
    wire signed [4:0] total_sum_col0;
    wire signed [4:0] total_sum_col1;
    wire signed [4:0] total_sum_col2;
    wire signed [4:0] total_sum_col3;
    wire [3:0] quantized_row;

    integer i;

    spi_nibble_slave u_spi_rx (
        .clk(clk),
        .rst_n(rst_n),
        .spi_sclk(spi_sclk),
        .spi_cs_n(spi_cs_n),
        .spi_mosi(spi_mosi),
        .nibble_out(spi_nibble),
        .nibble_valid(spi_nibble_valid)
    );

    nn_control_fsm u_fsm (
        .clk(clk),
        .rst_n(rst_n),
        .load_req(load_req),
        .execute_req(execute_req),
        .output_req(output_req),
        .load_done(load_done_r),
        .exec_done(exec_done_r),
        .output_done(output_done_r),
        .in_load_mode(load_mode),
        .exec_mode(exec_mode),
        .output_mode(output_mode),
        .busy(busy)
    );

    systolic_array_ws_4x4 #(.ACC_W(4)) u_array (
        .clk(clk),
        .rst_n(rst_n),
        .load_weight_en(array_load_weight_en),
        .load_weight_row_idx(array_load_weight_idx),
        .load_weight_row_data(array_load_weight_row),
        .start_vector(array_start_vector),
        .vector_in(array_vector_in),
        .out_valid(array_out_valid),
        .out_col_idx(array_out_col_idx),
        .out_data(array_out_data),
        .busy(array_busy),
        .done(array_done)
    );

    serial_nibble_tx u_tx (
        .clk(clk),
        .rst_n(rst_n),
        .nibble_in(tx_nibble_in),
        .load(tx_load),
        .shift_en(tx_shift_en),
        .serial_out(serial_out),
        .busy(tx_busy)
    );

    assign bias_col0 = bias_mem[{exec_row_idx, 2'd0}];
    assign bias_col1 = bias_mem[{exec_row_idx, 2'd1}];
    assign bias_col2 = bias_mem[{exec_row_idx, 2'd2}];
    assign bias_col3 = bias_mem[{exec_row_idx, 2'd3}];

    assign total_sum_col0 = raw_row_col0 + bias_col0;
    assign total_sum_col1 = raw_row_col1 + bias_col1;
    assign total_sum_col2 = raw_row_col2 + bias_col2;
    assign total_sum_col3 = raw_row_col3 + bias_col3;

    assign quantized_row[0] = (total_sum_col0 > 0);
    assign quantized_row[1] = (total_sum_col1 > 0);
    assign quantized_row[2] = (total_sum_col2 > 0);
    assign quantized_row[3] = (total_sum_col3 > 0);

    assign out_row_data = (out_rd_row == 2'd0) ? out_rows[0] :
                          (out_rd_row == 2'd1) ? out_rows[1] :
                          (out_rd_row == 2'd2) ? out_rows[2] :
                                                 out_rows[3];

    assign out_row_data_dbg    = out_row_data;
    assign spi_nibble_dbg      = spi_nibble;
    assign array_out_valid_dbg = array_out_valid;
    assign array_out_data_dbg  = array_out_data;
    assign quantized_value_dbg = quantized_row;

    always @(posedge clk) begin
        if (!rst_n) begin
            load_done_r           <= 1'b0;
            exec_done_r           <= 1'b0;
            output_done_r         <= 1'b0;
            load_active           <= 1'b0;
            load_target_latched   <= 2'd0;
            load_count            <= 5'd0;
            array_load_weight_en  <= 1'b0;
            array_load_weight_idx <= 2'd0;
            array_load_weight_row <= 4'd0;
            array_start_vector    <= 1'b0;
            array_vector_in       <= 4'd0;
            exec_row_idx          <= 2'd0;
            wt_load_row_idx       <= 2'd0;
            ex_state              <= EX_IDLE;
            raw_row_col0          <= 4'sd0;
            raw_row_col1          <= 4'sd0;
            raw_row_col2          <= 4'sd0;
            raw_row_col3          <= 4'sd0;
            out_rd_row            <= 2'd0;
            out_state             <= OUT_IDLE;
            out_row_idx           <= 2'd0;
            out_shift_count       <= 2'd0;
            tx_load               <= 1'b0;
            tx_shift_en           <= 1'b0;
            tx_nibble_in          <= 4'd0;
            for (i = 0; i < 4; i = i + 1) begin
                in_rows[i]  <= 4'd0;
                wt_rows[i]  <= 4'd0;
                out_rows[i] <= 4'd0;
            end
            for (i = 0; i < 16; i = i + 1)
                bias_mem[i] <= 4'sd0;
        end else begin
            load_done_r          <= 1'b0;
            exec_done_r          <= 1'b0;
            output_done_r        <= 1'b0;
            array_load_weight_en <= 1'b0;
            array_start_vector   <= 1'b0;
            tx_load              <= 1'b0;
            tx_shift_en          <= 1'b0;

            if (!load_mode) begin
                load_active         <= 1'b0;
                load_target_latched <= 2'd0;
                load_count          <= 5'd0;
            end else begin
                if (!load_active && load_req) begin
                    load_active         <= 1'b1;
                    load_target_latched <= load_target;
                    load_count          <= 5'd0;
                end else if (load_active && spi_nibble_valid) begin
                    case (load_target_latched)
                        LOAD_INPUT: begin
                            in_rows[load_count[1:0]] <= spi_nibble;
                            if (load_count == 5'd3) begin
                                load_done_r <= 1'b1;
                                load_active <= 1'b0;
                            end else begin
                                load_count <= load_count + 5'd1;
                            end
                        end
                        LOAD_WEIGHT: begin
                            wt_rows[load_count[1:0]] <= spi_nibble;
                            if (load_count == 5'd3) begin
                                load_done_r <= 1'b1;
                                load_active <= 1'b0;
                            end else begin
                                load_count <= load_count + 5'd1;
                            end
                        end
                        LOAD_BIAS: begin
                            bias_mem[load_count] <= $signed(spi_nibble);
                            if (load_count == 5'd15) begin
                                load_done_r <= 1'b1;
                                load_active <= 1'b0;
                            end else begin
                                load_count <= load_count + 5'd1;
                            end
                        end
                        default: begin
                            load_done_r <= 1'b1;
                            load_active <= 1'b0;
                        end
                    endcase
                end
            end

            if (!exec_mode) begin
                ex_state        <= EX_IDLE;
                exec_row_idx    <= 2'd0;
                wt_load_row_idx <= 2'd0;
            end else begin
                case (ex_state)
                    EX_IDLE: begin
                        wt_load_row_idx <= 2'd0;
                        exec_row_idx    <= 2'd0;
                        ex_state        <= EX_LOAD_WROW;
                    end

                    EX_LOAD_WROW: begin
                        array_load_weight_en  <= 1'b1;
                        array_load_weight_idx <= wt_load_row_idx;
                        array_load_weight_row <= wt_rows[wt_load_row_idx];
                        if (wt_load_row_idx == 2'd3) begin
                            ex_state <= EX_START_ROW;
                        end else begin
                            wt_load_row_idx <= wt_load_row_idx + 2'd1;
                        end
                    end

                    EX_START_ROW: begin
                        array_start_vector <= 1'b1;
                        array_vector_in    <= in_rows[exec_row_idx];
                        raw_row_col0       <= 4'sd0;
                        raw_row_col1       <= 4'sd0;
                        raw_row_col2       <= 4'sd0;
                        raw_row_col3       <= 4'sd0;
                        ex_state           <= EX_WAIT_ROW;
                    end

                    EX_WAIT_ROW: begin
                        if (array_out_valid) begin
                            case (array_out_col_idx)
                                2'd0: raw_row_col0 <= array_out_data;
                                2'd1: raw_row_col1 <= array_out_data;
                                2'd2: raw_row_col2 <= array_out_data;
                                default: raw_row_col3 <= array_out_data;
                            endcase
                        end

                        if (array_done)
                            ex_state <= EX_ADD_BIAS;
                    end

                    EX_ADD_BIAS: begin
                        out_rows[exec_row_idx] <= quantized_row;
                        if (exec_row_idx == 2'd3) begin
                            ex_state <= EX_FINISH;
                        end else begin
                            exec_row_idx <= exec_row_idx + 2'd1;
                            ex_state     <= EX_START_ROW;
                        end
                    end

                    EX_FINISH: begin
                        exec_done_r <= 1'b1;
                        ex_state    <= EX_IDLE;
                    end

                    default: ex_state <= EX_IDLE;
                endcase
            end

            if (!output_mode) begin
                out_state       <= OUT_IDLE;
                out_row_idx     <= 2'd0;
                out_shift_count <= 2'd0;
                out_rd_row      <= 2'd0;
            end else begin
                case (out_state)
                    OUT_IDLE: begin
                        out_row_idx <= 2'd0;
                        out_rd_row  <= 2'd0;
                        out_state   <= OUT_LOAD_NIB;
                    end

                    OUT_LOAD_NIB: begin
                        out_rd_row      <= out_row_idx;
                        tx_nibble_in    <= out_rows[out_row_idx];
                        tx_load         <= 1'b1;
                        out_shift_count <= 2'd0;
                        out_state       <= OUT_SHIFT_NIB;
                    end

                    OUT_SHIFT_NIB: begin
                        if (out_shift_count == 2'd3) begin
                            out_state <= OUT_NEXT_NIB;
                        end else begin
                            tx_shift_en     <= 1'b1;
                            out_shift_count <= out_shift_count + 2'd1;
                        end
                    end

                    OUT_NEXT_NIB: begin
                        if (out_row_idx == 2'd3) begin
                            out_state <= OUT_FINISH;
                        end else begin
                            out_row_idx <= out_row_idx + 2'd1;
                            out_state   <= OUT_LOAD_NIB;
                        end
                    end

                    OUT_FINISH: begin
                        output_done_r <= 1'b1;
                        out_state     <= OUT_IDLE;
                    end

                    default: out_state <= OUT_IDLE;
                endcase
            end
        end
    end
endmodule

