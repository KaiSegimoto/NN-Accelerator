`timescale 1ns/1ps
module tb_sram_4x4x8_4read;

    reg clk;
    reg write_enable, read_enable;
    reg [1:0] row_select, col_select;
    reg [7:0] write_data_in;

    wire [7:0] c0,c1,c2,c3;

    sram_4x4x8_4read dut(
        .clk(clk),
        .write_enable(write_enable),
        .read_enable(read_enable),
        .row_select(row_select),
        .col_select(col_select),
        .write_data_in(write_data_in),
        .read_col0_out(c0),
        .read_col1_out(c1),
        .read_col2_out(c2),
        .read_col3_out(c3)
    );

    initial clk=0;
    always #50 clk = ~clk; // 100ns period (10 MHz)

    task do_write(input [1:0] r, input [1:0] c, input [7:0] d);
        begin
            @(negedge clk);
            row_select=r; col_select=c; write_data_in=d;
            write_enable=1; read_enable=0;
            @(posedge clk);
            @(negedge clk);
            write_enable=0;
        end
    endtask

    task do_read4(input [1:0] r);
        begin
            @(negedge clk);
            row_select=r;
            write_enable=0; read_enable=1;
            @(posedge clk); #0.05;
            $display("row=%0d -> c0=%02h c1=%02h c2=%02h c3=%02h", r, c0,c1,c2,c3);
            @(negedge clk);
            read_enable=0;
        end
    endtask

    initial begin
        write_enable=0; read_enable=0;
        row_select=0; col_select=0; write_data_in=0;

        // row1: write 4 columns
        do_write(2'd1,2'd0,8'hA0);
        do_write(2'd1,2'd1,8'hB1);
        do_write(2'd1,2'd2,8'hC2);
        do_write(2'd1,2'd3,8'hD3);

        // one-cycle read out 4 columns
        do_read4(2'd1);

        $finish;
    end
endmodule



