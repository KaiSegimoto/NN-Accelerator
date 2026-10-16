`timescale 1ns/1ps
module tb_output_memory_4x4;
    reg clk;
    reg wr_en;
    reg [1:0] wr_row;
    reg [7:0] wr_d0, wr_d1, wr_d2, wr_d3;
    reg rd_en;
    reg [1:0] rd_row;
    wire [7:0] rd_c0, rd_c1, rd_c2, rd_c3;
    integer errors;

    output_memory_4x4 dut(
        .clk(clk),
        .wr_en(wr_en), .wr_row(wr_row), .wr_d0(wr_d0), .wr_d1(wr_d1), .wr_d2(wr_d2), .wr_d3(wr_d3),
        .rd_en(rd_en), .rd_row(rd_row), .rd_c0(rd_c0), .rd_c1(rd_c1), .rd_c2(rd_c2), .rd_c3(rd_c3)
    );

    initial clk = 0;
    always #50 clk = ~clk;

    initial begin
        errors = 0;
        wr_en = 0; rd_en = 0;
        wr_row = 0; rd_row = 0;
        wr_d0 = 0; wr_d1 = 0; wr_d2 = 0; wr_d3 = 0;

        @(negedge clk);
        wr_row = 2'd2;
        wr_d0 = 8'h10; wr_d1 = 8'h20; wr_d2 = 8'h30; wr_d3 = 8'h40;
        wr_en = 1;
        @(negedge clk);
        wr_en = 0;

        @(negedge clk);
        rd_row = 2'd2;
        rd_en = 1;
        @(posedge clk);
        #1;
        if (!(rd_c0==8'h10 && rd_c1==8'h20 && rd_c2==8'h30 && rd_c3==8'h40)) errors = errors + 1;
        @(negedge clk);
        rd_en = 0;

        if (errors == 0) $display("tb_output_memory_4x4 PASS");
        else             $display("tb_output_memory_4x4 FAIL, errors=%0d", errors);
        $finish;
    end
endmodule

