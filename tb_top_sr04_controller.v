`timescale 1ns / 1ps

module tb_top_sr04_controller();

    reg clk, rst, btn_R, echo;
    wire trig;
    wire [8:0] distance;
    wire [3:0] fnd_com;
    wire [7:0] fnd_data;

TOP_sr04_controller dut (
    .clk(clk),
    .rst(rst),
    .btn_R(btn_R),
    .echo(echo),
    .trig(trig),
    .distance(distance),
    .fnd_com(fnd_com),
    .fnd_data(fnd_data)
);

    always #5 clk = ~ clk;

    initial begin
        //rst
        rst=1;
        clk=0;
        btn_R=0;
        echo=0;
        #10;

        //idle->start
        rst=0;
        btn_R=1; //start
        #10;
        btn_R=0;

        //start->wait
        #2_000;

        //wait->response
        echo=1;
        #100_000; // 100us
        

        //response->idle
        echo=0;
        #7;

        $stop;
    end
endmodule
