`timescale 1ns/1ps
module tb_spi_output_fsm_4x4;
    reg clk;
    reg rst_n;
    reg start;
    wire done;
    reg ser_cs;

    wire out_rd_en;
    wire [1:0] out_rd_row;
    wire [7:0] out_c0, out_c1, out_c2, out_c3;

    wire tx_load;
    wire [7:0] tx_byte;
    wire tx_busy;
    wire tx_done;

    reg wr_en;
    reg [1:0] wr_row;
    reg [7:0] wr_d0, wr_d1, wr_d2, wr_d3;

    wire ser_dout;

    integer errors;
    integer load_cnt;
    reg [7:0] bytes_seen [0:15];

    output_memory_4x4 u_out(
        .clk(clk),
        .wr_en(wr_en), .wr_row(wr_row), .wr_d0(wr_d0), .wr_d1(wr_d1), .wr_d2(wr_d2), .wr_d3(wr_d3),
        .rd_en(out_rd_en), .rd_row(out_rd_row), .rd_c0(out_c0), .rd_c1(out_c1), .rd_c2(out_c2), .rd_c3(out_c3)
    );

    spi_output_fsm_4x4 dut(
        .clk(clk), .rst_n(rst_n), .start(start), .done(done), .ser_cs(ser_cs),
        .out_rd_en(out_rd_en), .out_rd_row(out_rd_row),
        .out_c0(out_c0), .out_c1(out_c1), .out_c2(out_c2), .out_c3(out_c3),
        .tx_load(tx_load), .tx_byte(tx_byte), .tx_busy(tx_busy), .tx_done(tx_done)
    );

    piso_8 u_piso(
        .clk(clk), .rst_n(rst_n), .ser_cs(ser_cs), .load(tx_load), .byte_in(tx_byte),
        .ser_dout(ser_dout), .busy(tx_busy), .done(tx_done)
    );

    initial clk = 0;
    always #50 clk = ~clk;

    task write_row;
        input [1:0] r;
        input [7:0] d0,d1,d2,d3;
        begin
            @(negedge clk);
            wr_row=r; wr_d0=d0; wr_d1=d1; wr_d2=d2; wr_d3=d3; wr_en=1;
            @(negedge clk);
            wr_en=0;
        end
    endtask

    always @(negedge clk) begin
        if (tx_load) begin
            bytes_seen[load_cnt] <= tx_byte;
            load_cnt <= load_cnt + 1;
        end
    end

    initial begin
        errors = 0;
        load_cnt = 0;
        rst_n = 0;
        start = 0;
        ser_cs = 1;
        wr_en = 0;
        wr_row = 0;
        wr_d0 = 0; wr_d1 = 0; wr_d2 = 0; wr_d3 = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;

        write_row(2'd0,8'h10,8'h11,8'h12,8'h13);
        write_row(2'd1,8'h20,8'h21,8'h22,8'h23);
        write_row(2'd2,8'h30,8'h31,8'h32,8'h33);
        write_row(2'd3,8'h40,8'h41,8'h42,8'h43);

        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        wait (done == 1'b1);
        @(posedge clk);

        $display("tb_spi_output_fsm_4x4 load_cnt=%0d", load_cnt);
        if (load_cnt != 16) errors = errors + 1;
        if (bytes_seen[0]  !== 8'h10) errors = errors + 1;
        if (bytes_seen[1]  !== 8'h11) errors = errors + 1;
        if (bytes_seen[2]  !== 8'h12) errors = errors + 1;
        if (bytes_seen[3]  !== 8'h13) errors = errors + 1;
        if (bytes_seen[12] !== 8'h40) errors = errors + 1;
        if (bytes_seen[15] !== 8'h43) errors = errors + 1;

        if (errors == 0) $display("tb_spi_output_fsm_4x4 PASS");
        else             $display("tb_spi_output_fsm_4x4 FAIL, errors=%0d", errors);
        $finish;
    end
endmodule


