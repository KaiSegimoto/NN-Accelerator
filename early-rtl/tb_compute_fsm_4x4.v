`timescale 1ns/1ps
module tb_compute_fsm_4x4;
    reg clk;
    reg rst_n;
    reg start;
    wire done;

    wire act_rd_en;
    wire [1:0] act_row;
    wire [7:0] act_c0, act_c1, act_c2, act_c3;

    wire wgt_rd_en;
    wire [1:0] wgt_row;
    wire [7:0] wgt_c0, wgt_c1, wgt_c2, wgt_c3;

    reg signed [23:0] bias0, bias1, bias2, bias3;

    wire out_wr_en;
    wire [1:0] out_wr_row;
    wire [7:0] out_wr_d0, out_wr_d1, out_wr_d2, out_wr_d3;

    reg out_rd_en;
    reg [1:0] out_rd_row;
    wire [7:0] out_rd_c0, out_rd_c1, out_rd_c2, out_rd_c3;

    reg act_we, wgt_we;
    reg [1:0] act_wr_row, act_wr_col, wgt_wr_row, wgt_wr_col;
    reg [7:0] act_wr_data, wgt_wr_data;

    integer errors;

    sram_4x4x8_4read u_act(
        .clk(clk),
        .write_enable(act_we),
        .read_enable(act_rd_en),
        .row_select(act_we ? act_wr_row : act_row),
        .col_select(act_we ? act_wr_col : 2'd0),
        .write_data_in(act_wr_data),
        .read_col0_out(act_c0), .read_col1_out(act_c1), .read_col2_out(act_c2), .read_col3_out(act_c3)
    );

    sram_4x4x8_4read u_wgt(
        .clk(clk),
        .write_enable(wgt_we),
        .read_enable(wgt_rd_en),
        .row_select(wgt_we ? wgt_wr_row : wgt_row),
        .col_select(wgt_we ? wgt_wr_col : 2'd0),
        .write_data_in(wgt_wr_data),
        .read_col0_out(wgt_c0), .read_col1_out(wgt_c1), .read_col2_out(wgt_c2), .read_col3_out(wgt_c3)
    );

    output_memory_4x4 u_out(
        .clk(clk),
        .wr_en(out_wr_en), .wr_row(out_wr_row),
        .wr_d0(out_wr_d0), .wr_d1(out_wr_d1), .wr_d2(out_wr_d2), .wr_d3(out_wr_d3),
        .rd_en(out_rd_en), .rd_row(out_rd_row),
        .rd_c0(out_rd_c0), .rd_c1(out_rd_c1), .rd_c2(out_rd_c2), .rd_c3(out_rd_c3)
    );

    compute_fsm_4x4 dut(
        .clk(clk), .rst_n(rst_n),
        .start(start), .done(done),
        .act_rd_en(act_rd_en), .act_row(act_row),
        .act_c0(act_c0), .act_c1(act_c1), .act_c2(act_c2), .act_c3(act_c3),
        .wgt_rd_en(wgt_rd_en), .wgt_row(wgt_row),
        .wgt_c0(wgt_c0), .wgt_c1(wgt_c1), .wgt_c2(wgt_c2), .wgt_c3(wgt_c3),
        .bias0(bias0), .bias1(bias1), .bias2(bias2), .bias3(bias3),
        .out_wr_en(out_wr_en), .out_wr_row(out_wr_row),
        .out_wr_d0(out_wr_d0), .out_wr_d1(out_wr_d1), .out_wr_d2(out_wr_d2), .out_wr_d3(out_wr_d3)
    );

    initial clk = 0;
    always #50 clk = ~clk;

    task act_write;
        input [1:0] r, c;
        input [7:0] d;
        begin
            @(negedge clk);
            act_wr_row = r; act_wr_col = c; act_wr_data = d; act_we = 1;
            @(negedge clk);
            act_we = 0;
        end
    endtask

    task wgt_write;
        input [1:0] r, c;
        input [7:0] d;
        begin
            @(negedge clk);
            wgt_wr_row = r; wgt_wr_col = c; wgt_wr_data = d; wgt_we = 1;
            @(negedge clk);
            wgt_we = 0;
        end
    endtask

    task out_read_check;
        input [1:0] r;
        input [7:0] e0, e1, e2, e3;
        begin
            @(negedge clk);
            out_rd_row = r; out_rd_en = 1;
            @(posedge clk);
            #1;
            if (!(out_rd_c0==e0 && out_rd_c1==e1 && out_rd_c2==e2 && out_rd_c3==e3)) begin
                $display("[FAIL] row=%0d got=%02h %02h %02h %02h exp=%02h %02h %02h %02h",
                    r, out_rd_c0,out_rd_c1,out_rd_c2,out_rd_c3,e0,e1,e2,e3);
                errors = errors + 1;
            end
            @(negedge clk);
            out_rd_en = 0;
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 0;
        start = 0;
        bias0 = 0; bias1 = 0; bias2 = 0; bias3 = 0;
        act_we = 0; wgt_we = 0;
        act_wr_row = 0; act_wr_col = 0; act_wr_data = 0;
        wgt_wr_row = 0; wgt_wr_col = 0; wgt_wr_data = 0;
        out_rd_en = 0; out_rd_row = 0;

        repeat (2) @(posedge clk);
        rst_n = 1;

        // A = identity
        act_write(2'd0,2'd0,8'd1); act_write(2'd0,2'd1,8'd0); act_write(2'd0,2'd2,8'd0); act_write(2'd0,2'd3,8'd0);
        act_write(2'd1,2'd0,8'd0); act_write(2'd1,2'd1,8'd1); act_write(2'd1,2'd2,8'd0); act_write(2'd1,2'd3,8'd0);
        act_write(2'd2,2'd0,8'd0); act_write(2'd2,2'd1,8'd0); act_write(2'd2,2'd2,8'd1); act_write(2'd2,2'd3,8'd0);
        act_write(2'd3,2'd0,8'd0); act_write(2'd3,2'd1,8'd0); act_write(2'd3,2'd2,8'd0); act_write(2'd3,2'd3,8'd1);

        // W rows
        wgt_write(2'd0,2'd0,8'd1);  wgt_write(2'd0,2'd1,8'd2);  wgt_write(2'd0,2'd2,8'd3);  wgt_write(2'd0,2'd3,8'd4);
        wgt_write(2'd1,2'd0,8'd5);  wgt_write(2'd1,2'd1,8'd6);  wgt_write(2'd1,2'd2,8'd7);  wgt_write(2'd1,2'd3,8'd8);
        wgt_write(2'd2,2'd0,8'd9);  wgt_write(2'd2,2'd1,8'd10); wgt_write(2'd2,2'd2,8'd11); wgt_write(2'd2,2'd3,8'd12);
        wgt_write(2'd3,2'd0,8'd13); wgt_write(2'd3,2'd1,8'd14); wgt_write(2'd3,2'd2,8'd15); wgt_write(2'd3,2'd3,8'd16);

        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        wait (done == 1'b1);
        @(posedge clk);

        out_read_check(2'd0,8'd1,8'd2,8'd3,8'd4);
        out_read_check(2'd1,8'd5,8'd6,8'd7,8'd8);
        out_read_check(2'd2,8'd9,8'd10,8'd11,8'd12);
        out_read_check(2'd3,8'd13,8'd14,8'd15,8'd16);

        if (errors == 0) $display("tb_compute_fsm_4x4 PASS");
        else             $display("tb_compute_fsm_4x4 FAIL, errors=%0d", errors);
        $finish;
    end
endmodule

