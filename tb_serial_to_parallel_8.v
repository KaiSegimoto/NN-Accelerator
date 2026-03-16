`timescale 1ns/1ps
module tb_serial_to_parallel_8;
    reg clk;
    reg rst_n;
    reg ser_cs;
    reg ser_din;
    wire [7:0] rx_byte;
    wire rx_valid;
    integer errors;

    serial_to_parallel_8 dut(
        .clk(clk),
        .rst_n(rst_n),
        .ser_cs(ser_cs),
        .ser_din(ser_din),
        .rx_byte(rx_byte),
        .rx_valid(rx_valid)
    );

initial clk = 0;
always #50 clk = ~clk;

    task send_byte_msb;
        input [7:0] b;
        integer i;
        begin
            ser_cs = 1'b1;
            for (i = 7; i >= 0; i = i - 1) begin
                @(negedge clk);
                ser_din = b[i];
            end
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 0;
        ser_cs = 0;
        ser_din = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;

        send_byte_msb(8'hA5);
        wait (rx_valid == 1'b1);
        #1;
        if (rx_byte != 8'hA5) begin
            $display("[FAIL] expected A5, got valid=%0b byte=%02h", rx_valid, rx_byte);
            errors = errors + 1;
        end

        send_byte_msb(8'h3C);
        wait (rx_valid == 1'b1);
        #1;
        if (rx_byte != 8'h3C) begin
            $display("[FAIL] expected 3C, got valid=%0b byte=%02h", rx_valid, rx_byte);
            errors = errors + 1;
        end

        ser_cs = 0;
        repeat (2) @(posedge clk);

        if (errors == 0) $display("tb_serial_to_parallel_8 PASS");
        else             $display("tb_serial_to_parallel_8 FAIL, errors=%0d", errors);
        $finish;
    end
endmodule


