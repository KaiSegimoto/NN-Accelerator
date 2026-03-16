`timescale 1ns/1ps
module tb_system_integration_4x4;
    reg clk;
    reg rst_n;
    reg ser_cs;
    reg ser_din;
    wire ser_dout;

    reg        dbg_out_rd_en;
    reg  [1:0] dbg_out_rd_row;
    wire [7:0] dbg_out_c0, dbg_out_c1, dbg_out_c2, dbg_out_c3;

    integer errors;
    integer tx_cnt;
    integer timeout_cnt;
    reg [7:0] tx_bytes [0:15];

    top_fsm_4x4_system dut(
        .clk(clk),
        .rst_n(rst_n),
        .ser_cs(ser_cs),
        .ser_din(ser_din),
        .ser_dout(ser_dout),
        .dbg_out_rd_en(dbg_out_rd_en),
        .dbg_out_rd_row(dbg_out_rd_row),
        .dbg_out_c0(dbg_out_c0),
        .dbg_out_c1(dbg_out_c1),
        .dbg_out_c2(dbg_out_c2),
        .dbg_out_c3(dbg_out_c3)
    );

    initial clk = 0;
    always #50 clk = ~clk;

    always @(posedge clk) begin
        if (rst_n && dut.tx_load) begin
            tx_bytes[tx_cnt] <= dut.tx_byte;
            tx_cnt <= tx_cnt + 1;
        end
    end

    task send_spi_byte;
        input [7:0] b;
        integer i;
        begin
            for (i = 7; i >= 0; i = i - 1) begin
                @(negedge clk);
                ser_din = b[i];
            end
        end
    endtask

    task end_frame;
        begin
            @(negedge clk);
            ser_cs = 1'b0;
            ser_din = 1'b0;
            @(negedge clk);
        end
    endtask

    task send_spi_byte_aligned;
        input [7:0] b;
        input       first_byte;
        integer i;
        begin
            if (first_byte) begin
                @(negedge clk);
                ser_cs = 1'b1;
                ser_din = b[7];
                for (i = 6; i >= 0; i = i - 1) begin
                    @(negedge clk);
                    ser_din = b[i];
                end
            end else begin
                for (i = 7; i >= 0; i = i - 1) begin
                    @(negedge clk);
                    ser_din = b[i];
                end
            end
        end
    endtask

    task send_act_write;
        input [1:0] r, c;
        input [7:0] d;
        begin
            send_spi_byte_aligned(8'hA0, 1'b1);
            send_spi_byte({6'd0, r});
            send_spi_byte({6'd0, c});
            send_spi_byte(d);
            end_frame;
        end
    endtask

    task send_wgt_write;
        input [1:0] r, c;
        input [7:0] d;
        begin
            send_spi_byte_aligned(8'hB0, 1'b1);
            send_spi_byte({6'd0, r});
            send_spi_byte({6'd0, c});
            send_spi_byte(d);
            end_frame;
        end
    endtask

    task send_bias_write;
        input [1:0] c;
        input [23:0] d;
        begin
            send_spi_byte_aligned(8'hC0, 1'b1);
            send_spi_byte({6'd0, c});
            send_spi_byte(d[23:16]);
            send_spi_byte(d[15:8]);
            send_spi_byte(d[7:0]);
            end_frame;
        end
    endtask

    task start_compute;
        begin
            send_spi_byte_aligned(8'hD0, 1'b1);
            end_frame;
        end
    endtask

    task start_output_stream;
        begin
            send_spi_byte_aligned(8'hE0, 1'b1);
            // Keep CS asserted for the whole output stream.
        end
    endtask

    task stop_output_stream;
        begin
            end_frame;
        end
    endtask

    task check_row;
        input [1:0] r;
        input [7:0] e0, e1, e2, e3;
        begin
            @(negedge clk);
            dbg_out_rd_row = r;
            dbg_out_rd_en = 1'b1;
            @(posedge clk);
            #1;
            if (!(dbg_out_c0 == e0 && dbg_out_c1 == e1 && dbg_out_c2 == e2 && dbg_out_c3 == e3)) begin
                $display("[FAIL] dbg row=%0d got=%02h %02h %02h %02h exp=%02h %02h %02h %02h",
                    r, dbg_out_c0, dbg_out_c1, dbg_out_c2, dbg_out_c3, e0, e1, e2, e3);
                errors = errors + 1;
            end
            @(negedge clk);
            dbg_out_rd_en = 1'b0;
        end
    endtask

    initial begin
        errors = 0;
        tx_cnt = 0;
        rst_n = 0;
        ser_cs = 0;
        ser_din = 0;
        dbg_out_rd_en = 0;
        dbg_out_rd_row = 0;

        repeat (3) @(posedge clk);
        rst_n = 1;

        // A = I
        send_act_write(2'd0,2'd0,8'd1); send_act_write(2'd0,2'd1,8'd0); send_act_write(2'd0,2'd2,8'd0); send_act_write(2'd0,2'd3,8'd0);
        send_act_write(2'd1,2'd0,8'd0); send_act_write(2'd1,2'd1,8'd1); send_act_write(2'd1,2'd2,8'd0); send_act_write(2'd1,2'd3,8'd0);
        send_act_write(2'd2,2'd0,8'd0); send_act_write(2'd2,2'd1,8'd0); send_act_write(2'd2,2'd2,8'd1); send_act_write(2'd2,2'd3,8'd0);
        send_act_write(2'd3,2'd0,8'd0); send_act_write(2'd3,2'd1,8'd0); send_act_write(2'd3,2'd2,8'd0); send_act_write(2'd3,2'd3,8'd1);

        // W
        send_wgt_write(2'd0,2'd0,8'd1);  send_wgt_write(2'd0,2'd1,8'd2);  send_wgt_write(2'd0,2'd2,8'd3);  send_wgt_write(2'd0,2'd3,8'd4);
        send_wgt_write(2'd1,2'd0,8'd5);  send_wgt_write(2'd1,2'd1,8'd6);  send_wgt_write(2'd1,2'd2,8'd7);  send_wgt_write(2'd1,2'd3,8'd8);
        send_wgt_write(2'd2,2'd0,8'd9);  send_wgt_write(2'd2,2'd1,8'd10); send_wgt_write(2'd2,2'd2,8'd11); send_wgt_write(2'd2,2'd3,8'd12);
        send_wgt_write(2'd3,2'd0,8'd13); send_wgt_write(2'd3,2'd1,8'd14); send_wgt_write(2'd3,2'd2,8'd15); send_wgt_write(2'd3,2'd3,8'd16);

        // bias all zero
        send_bias_write(2'd0,24'd0);
        send_bias_write(2'd1,24'd0);
        send_bias_write(2'd2,24'd0);
        send_bias_write(2'd3,24'd0);

        start_compute;

        timeout_cnt = 0;
        while (dut.compute_done !== 1'b1 && timeout_cnt < 1000) begin
            @(posedge clk);
            timeout_cnt = timeout_cnt + 1;
        end
        if (dut.compute_done !== 1'b1) begin
            $display("[FAIL] timeout waiting compute_done");
            errors = errors + 1;
        end

        check_row(2'd0, 8'd1,  8'd2,  8'd3,  8'd4);
        check_row(2'd1, 8'd5,  8'd6,  8'd7,  8'd8);
        check_row(2'd2, 8'd9,  8'd10, 8'd11, 8'd12);
        check_row(2'd3, 8'd13, 8'd14, 8'd15, 8'd16);

        start_output_stream;

        timeout_cnt = 0;
        while (dut.stream_done !== 1'b1 && timeout_cnt < 4000) begin
            @(posedge clk);
            timeout_cnt = timeout_cnt + 1;
        end
        if (dut.stream_done !== 1'b1) begin
            $display("[FAIL] timeout waiting stream_done");
            errors = errors + 1;
        end

        stop_output_stream;
        @(posedge clk);

        $display("tb_system_integration_4x4 tx_cnt=%0d", tx_cnt);
        if (tx_cnt != 16) errors = errors + 1;
        if (tx_bytes[0]  !== 8'd1)  errors = errors + 1;
        if (tx_bytes[1]  !== 8'd2)  errors = errors + 1;
        if (tx_bytes[2]  !== 8'd3)  errors = errors + 1;
        if (tx_bytes[3]  !== 8'd4)  errors = errors + 1;
        if (tx_bytes[12] !== 8'd13) errors = errors + 1;
        if (tx_bytes[15] !== 8'd16) errors = errors + 1;

        if (errors == 0) $display("tb_system_integration_4x4 PASS");
        else             $display("tb_system_integration_4x4 FAIL, errors=%0d", errors);
        $finish;
    end
endmodule
