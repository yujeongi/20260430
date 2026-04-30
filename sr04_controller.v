`timescale 1ns / 1ps

module TOP_sr04_controller (
    input        clk,
    input        rst,
    input        btnR,
    input        echo,
    output       trig,
    output [8:0] distance,  // +
    output [3:0] fnd_com,
    output [7:0] fnd_data
);

    wire w_tick_us;
    wire w_sr04_start;
    wire [8:0] w_distance;

    ila_0 U_ILA0(
    .clk(clk), //only system clock
    .probe0(w_sr04_start),
    .probe1(w_distance)
);

    button_debounce U_BD_SR04_START (
        .clk  (clk),
        .rst  (rst),
        .i_btn(btnR),
        .o_btn(w_sr04_start)
    );

    sr04_controller U_SR04_CNTL (
        .clk       (clk),
        .rst       (rst),
        .sr04_start(w_sr04_start),
        .tick_us   (w_tick_us),
        .echo      (echo),
        .trig      (trig),
        .distance  (w_distance)
    );

    tick_gen_us U_TICK_GEN_US (
        .clk    (clk),
        .rst    (rst),
        .tick_us(w_tick_us)
    );

    fnd_controller U_FND_CNTL (
        .clk     (clk),
        .rst     (rst),
        .fnd_in  ({5'b00000, w_distance}), //lsb
        .fnd_com (fnd_com),
        .fnd_data(fnd_data)
    );
endmodule



module sr04_controller (
    input        clk,
    input        rst,
    input        sr04_start,
    input        tick_us,
    input        echo,
    output       trig,
    output [8:0] distance
);

    parameter IDLE = 0, START = 1, WAIT = 2, RESPONSE = 3;

    reg trig_reg, trig_next;
    reg [8:0] distance_reg, distance_next;
    reg [3:0] tick_cnt_reg, tick_cnt_next;
    reg [1:0] c_state, n_state;
    reg [5:0] e_cnt_reg, e_cnt_next; //echo count _ 58
    assign trig = trig_reg;
    assign distance = distance_reg;  //cm, 근데 오류

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            trig_reg     <= 0;
            distance_reg <= 0;
            tick_cnt_reg <= 0;
            c_state      <= 0;
        end else begin
            trig_reg     <= trig_next;
            distance_reg <= distance_next;
            tick_cnt_reg <= tick_cnt_next;
            c_state      <= n_state;
        end
    end

    always @(*) begin
        trig_next     = trig_reg;
        distance_next = distance_reg;
        tick_cnt_next = tick_cnt_reg;
        n_state       = c_state;
        case (c_state)
            IDLE: begin
                trig_next = 0;
                if (sr04_start) begin
                    n_state = START;
                end else begin
                    n_state = IDLE;
                end
            end
            START: begin
                trig_next = 1;
                if (tick_us) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 12) begin
                        //tick_cnt_next = 0;
                        n_state = WAIT;
                    end
                end
            end
            WAIT: begin
                trig_next = 0;
                if (tick_us) begin
                    //tick_cnt_next = tick_cnt_reg + 1;
                    if (echo) begin
                        tick_cnt_next = 0;
                        n_state = RESPONSE;
                    end
                end
            end
            RESPONSE: begin
                if (tick_us) begin
                    e_cnt_next = e_cnt_reg + 1;
                    if (!echo) begin
                        distance_next = distance_reg / 58;
                        n_state = IDLE;
                    end
                end
            end
            default: ;
        endcase
    end

endmodule

module sr04_controller (
    input clk,
    input rst,
    input sr04_start,
    input tick_us,
    input echo,
    output trig,
    output [8:0] distance
);

    parameter IDLE = 0, START = 1, WAIT = 2, RESPONSE = 3;
    reg [1:0] c_state, n_state;
    reg trig_reg, trig_next;
    reg [3:0] tick_cnt_reg, tick_cnt_next;
    reg [5:0] e_cnt_reg, e_cnt_next;
    reg [8:0] dist_reg, dist_next;

    assign distance = dist_reg;
    assign trig = trig_reg;

    //state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            trig_reg <= 1'b0;
            e_cnt_reg <= 6'b0;
            tick_cnt_reg <= 4'b0;
            dist_reg <= 9'b0;
        end else begin
            c_state <= n_state;
            trig_reg <= trig_next;
            e_cnt_reg <= e_cnt_next;
            tick_cnt_reg <= tick_cnt_next;
            dist_reg <= dist_next;
        end
    end

    //
    always @(*) begin
        n_state = c_state;
        trig_next = trig_reg;
        e_cnt_next = e_cnt_reg;
        tick_cnt_next = tick_cnt_reg;
        dist_next = dist_reg;
        case (c_state)
            IDLE: begin
                trig_next = 0;
                tick_cnt_next = 0;
                if (sr04_start) begin
                    n_state = START;
                end
            end
            START: begin
                trig_next = 1;
                if (tick_us) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg >= 11) begin
                        n_state = WAIT;
                    end
                end
            end
            WAIT: begin  // noise 끼니까 metastable 될 수 있어서
                // 걍 tick 들어올때마다 response로, 더 안전하게 하려면 synchronizer
                // echo가 외부에서 cdc로 들어오니까
                trig_next = 0;
                if (tick_us && echo) begin
                    n_state = RESPONSE;
                end
                dist_next = 0;
            end
            RESPONSE: begin
                if (tick_us) begin  // if echo == 0
                    e_cnt_next = e_cnt_reg + 1;
                    if (!echo) begin
                        //dist_next = e_cnt_reg / 58; // centimeter
                        n_state = IDLE;
                    end else begin  // if echo == 1
                        if (e_cnt_reg == 58) begin
                            dist_next  = dist_reg + 1;
                            e_cnt_next = 0;
                        end else begin
                            n_state = c_state;
                        end
                    end
                end
            end
        endcase
    end

endmodule


module tick_gen_us (  //나같으면 us안함. 바꾸려면 바꾸던가.
    input      clk,
    input      rst,
    output reg tick_us
);
    parameter F_COUNT = 100_000_000 / 1_000_000;  //1us
    reg [$clog2(F_COUNT-1):0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            tick_us     <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                tick_us     <= 1'b1;
            end else begin
                tick_us <= 1'b0;
            end
        end
    end

endmodule


