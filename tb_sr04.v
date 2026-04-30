`timescale 1ns / 1ps

module tb_sr04 ();

    parameter US_DELAY = 1000, MS_DEALY = 1_000_000;

    reg        clk;
    reg        rst;
    reg        sr04_start;
    reg        echo;
    wire       trig;
    wire [8:0] distance;
    wire       w_tick_us;

    tick_gen_us dut2 (  //나같으면 us안함. 바꾸려면 바꾸던가.
        .clk(clk),
        .rst(rst),
        .tick_us(w_tick_us)
    );

    sr04_controller dut (
        .clk(clk),
        .rst(rst),
        .sr04_start(sr04_start),
        .tick_us(w_tick_us),
        .echo(echo),
        .trig(trig),
        .distance(distance)
    );

    always #5 clk = ~ clk;

    initial begin
        clk = 0;
        rst = 1;
        sr04_start = 0;
        echo=0;
        #20;
        rst=0;
        #20;


        //start sr04
        @(posedge clk);
        sr04_start=1;
        @(posedge clk);
        sr04_start=0;
        
        //echo response
        echo=1;
        #(US_DELAY *20);
        echo=0;

        //@(negedge trig);

    end

endmodule
