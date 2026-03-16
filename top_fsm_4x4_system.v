module top_fsm_4x4_system (
    input  wire        clk,
    input  wire        rst_n,

    // SPI-like serial interface (bit clock = clk)
    input  wire        ser_cs,    // CS active HIGH
    input  wire        ser_din,   // MOSI
    output wire        ser_dout,  // MISO

    // optional debug: parallel readout of one output row
    input  wire        dbg_out_rd_en,
    input  wire [1:0]  dbg_out_rd_row,
    output wire [7:0]  dbg_out_c0,
    output wire [7:0]  dbg_out_c1,
    output wire [7:0]  dbg_out_c2,
    output wire [7:0]  dbg_out_c3
);

    // -----------------------
    // RX: serial -> byte
    // -----------------------
    wire [7:0] rx_byte;
    wire       rx_valid;

    serial_to_parallel_8 u_rx (
        .clk(clk),
        .rst_n(rst_n),
        .ser_cs(ser_cs),
        .ser_din(ser_din),
        .rx_byte(rx_byte),
        .rx_valid(rx_valid)
    );

    // -----------------------
    // Command controller
    // -----------------------
    wire        act_wr_pulse, wgt_wr_pulse, bias_wr_pulse;
    wire [1:0]  act_wr_row, act_wr_col, wgt_wr_row, wgt_wr_col, bias_col;
    wire [7:0]  act_wr_data, wgt_wr_data;
    wire [23:0] bias_data;
    wire        start_compute_pulse, start_output_pulse;

    cmd_controller_4x4 u_cmd (
        .clk(clk),
        .rst_n(rst_n),
        .rx_byte(rx_byte),
        .rx_valid(rx_valid),

        .act_wr_pulse(act_wr_pulse),
        .act_wr_row(act_wr_row),
        .act_wr_col(act_wr_col),
        .act_wr_data(act_wr_data),

        .wgt_wr_pulse(wgt_wr_pulse),
        .wgt_wr_row(wgt_wr_row),
        .wgt_wr_col(wgt_wr_col),
        .wgt_wr_data(wgt_wr_data),

        .bias_wr_pulse(bias_wr_pulse),
        .bias_col(bias_col),
        .bias_data(bias_data),

        .start_compute_pulse(start_compute_pulse),
        .start_output_pulse(start_output_pulse)
    );

    // -----------------------
    // Bias regs (signed 24-bit)
    // -----------------------
    reg signed [23:0] bias0, bias1, bias2, bias3;
    always @(posedge clk) begin
        if (!rst_n) begin
            bias0 <= 24'sd0;
            bias1 <= 24'sd0;
            bias2 <= 24'sd0;
            bias3 <= 24'sd0;
        end else if (bias_wr_pulse) begin
            case (bias_col)
                2'd0: bias0 <= bias_data;
                2'd1: bias1 <= bias_data;
                2'd2: bias2 <= bias_data;
                2'd3: bias3 <= bias_data;
                default: ;
            endcase
        end
    end

    // -----------------------
    // Activation SRAM
    // -----------------------
    wire [7:0] act_r0, act_r1, act_r2, act_r3;
    wire       act_rd_en;
    wire [1:0] act_rd_row;

    sram_4x4x8_4read u_act_sram (
        .clk(clk),
        .write_enable(act_wr_pulse),
        .read_enable(act_rd_en),

        .row_select(act_wr_pulse ? act_wr_row : act_rd_row),
        .col_select(act_wr_col),
        .write_data_in(act_wr_data),

        .read_col0_out(act_r0),
        .read_col1_out(act_r1),
        .read_col2_out(act_r2),
        .read_col3_out(act_r3)
    );

    // -----------------------
    // Weight SRAM
    // -----------------------
    wire [7:0] wgt_r0, wgt_r1, wgt_r2, wgt_r3;
    wire       wgt_rd_en;
    wire [1:0] wgt_rd_row;

    sram_4x4x8_4read u_wgt_sram (
        .clk(clk),
        .write_enable(wgt_wr_pulse),
        .read_enable(wgt_rd_en),

        .row_select(wgt_wr_pulse ? wgt_wr_row : wgt_rd_row),
        .col_select(wgt_wr_col),
        .write_data_in(wgt_wr_data),

        .read_col0_out(wgt_r0),
        .read_col1_out(wgt_r1),
        .read_col2_out(wgt_r2),
        .read_col3_out(wgt_r3)
    );

    // -----------------------
    // Output memory
    // -----------------------
    wire        out_wr_en;
    wire [1:0]  out_wr_row;
    wire [7:0]  out_wr_d0, out_wr_d1, out_wr_d2, out_wr_d3;

    wire        out_rd_en;
    wire [1:0]  out_rd_row;
    wire [7:0]  out_rd_c0, out_rd_c1, out_rd_c2, out_rd_c3;

    output_memory_4x4 u_outmem (
        .clk(clk),
        .wr_en(out_wr_en),
        .wr_row(out_wr_row),
        .wr_d0(out_wr_d0),
        .wr_d1(out_wr_d1),
        .wr_d2(out_wr_d2),
        .wr_d3(out_wr_d3),

        // shared read port (debug OR stream)
        .rd_en(out_rd_en),
        .rd_row(out_rd_row),
        .rd_c0(out_rd_c0),
        .rd_c1(out_rd_c1),
        .rd_c2(out_rd_c2),
        .rd_c3(out_rd_c3)
    );

    // debug taps
    assign dbg_out_c0 = out_rd_c0;
    assign dbg_out_c1 = out_rd_c1;
    assign dbg_out_c2 = out_rd_c2;
    assign dbg_out_c3 = out_rd_c3;

    // -----------------------
    // Compute FSM
    // -----------------------
    wire compute_done;

    compute_fsm_4x4 u_compute (
        .clk(clk),
        .rst_n(rst_n),

        .start(start_compute_pulse),
        .done(compute_done),

        .act_rd_en(act_rd_en),
        .act_row(act_rd_row),
        .act_c0(act_r0),
        .act_c1(act_r1),
        .act_c2(act_r2),
        .act_c3(act_r3),

        .wgt_rd_en(wgt_rd_en),
        .wgt_row(wgt_rd_row),
        .wgt_c0(wgt_r0),
        .wgt_c1(wgt_r1),
        .wgt_c2(wgt_r2),
        .wgt_c3(wgt_r3),

        .bias0(bias0),
        .bias1(bias1),
        .bias2(bias2),
        .bias3(bias3),

        .out_wr_en(out_wr_en),
        .out_wr_row(out_wr_row),
        .out_wr_d0(out_wr_d0),
        .out_wr_d1(out_wr_d1),
        .out_wr_d2(out_wr_d2),
        .out_wr_d3(out_wr_d3)
    );

    // -----------------------
    // Output streaming FSM + PISO
    // -----------------------
    wire stream_done;
    wire tx_load;
    wire [7:0] tx_byte;
    wire tx_busy, tx_done;

    // read mux: either debug read OR stream read
    // priority: stream when active (simpler), otherwise debug
    // We detect "stream active" by tx_busy or internal start tracking:
    // easiest: let stream FSM drive rd_en/rd_row; when idle, use debug.
    wire stream_rd_en;
    wire [1:0] stream_rd_row;

    assign out_rd_en  = stream_rd_en ? 1'b1 : dbg_out_rd_en;
    assign out_rd_row = stream_rd_en ? stream_rd_row : dbg_out_rd_row;

    spi_output_fsm_4x4 u_stream (
        .clk(clk),
        .rst_n(rst_n),

        .start(start_output_pulse),
        .done(stream_done),

        .ser_cs(ser_cs),

        .out_rd_en(stream_rd_en),
        .out_rd_row(stream_rd_row),
        .out_c0(out_rd_c0),
        .out_c1(out_rd_c1),
        .out_c2(out_rd_c2),
        .out_c3(out_rd_c3),

        .tx_load(tx_load),
        .tx_byte(tx_byte),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );

    piso_8 u_piso (
        .clk(clk),
        .rst_n(rst_n),
        .ser_cs(ser_cs),
        .load(tx_load),
        .byte_in(tx_byte),
        .ser_dout(ser_dout),
        .busy(tx_busy),
        .done(tx_done)
    );

endmodule