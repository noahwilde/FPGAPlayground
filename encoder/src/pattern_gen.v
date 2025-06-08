// Simple 640x480 pattern generator producing a moving color gradient
// Outputs pixel data along with sync and data enable
module pattern_gen (
    input        clk,
    input        rst,
    output       hsync,
    output       vsync,
    output       de,
    output [7:0] red,
    output [7:0] green,
    output [7:0] blue
);

    parameter H_ACTIVE = 640;
    parameter H_FP     = 16;
    parameter H_SYNC   = 96;
    parameter H_BP     = 48;
    parameter V_ACTIVE = 480;
    parameter V_FP     = 10;
    parameter V_SYNC   = 2;
    parameter V_BP     = 33;

    localparam H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;
    localparam V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP;

    reg [11:0] h_cnt = 0;
    reg [11:0] v_cnt = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            h_cnt <= 0;
            v_cnt <= 0;
        end else begin
            if (h_cnt == H_TOTAL-1) begin
                h_cnt <= 0;
                if (v_cnt == V_TOTAL-1)
                    v_cnt <= 0;
                else
                    v_cnt <= v_cnt + 1;
            end else begin
                h_cnt <= h_cnt + 1;
            end
        end
    end

    assign hsync = (h_cnt >= H_ACTIVE + H_FP) && (h_cnt < H_ACTIVE + H_FP + H_SYNC);
    assign vsync = (v_cnt >= V_ACTIVE + V_FP) && (v_cnt < V_ACTIVE + V_FP + V_SYNC);
    assign de    = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);

    assign red   = h_cnt[7:0];
    assign green = v_cnt[7:0];
    assign blue  = (h_cnt[7:0] + v_cnt[7:0]);

endmodule
