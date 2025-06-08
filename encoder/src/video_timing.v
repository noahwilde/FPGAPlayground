module video_timing #(
    parameter H_ACTIVE = 640,
    parameter H_FP     = 16,
    parameter H_SYNC   = 96,
    parameter H_BP     = 48,
    parameter V_ACTIVE = 480,
    parameter V_FP     = 10,
    parameter V_SYNC   = 2,
    parameter V_BP     = 33
)(
    input  clk,
    input  rst,
    output reg [11:0] x = 0,
    output reg [11:0] y = 0,
    output hsync,
    output vsync,
    output de
);

    localparam H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;
    localparam V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x <= 0;
            y <= 0;
        end else begin
            if (x == H_TOTAL-1) begin
                x <= 0;
                if (y == V_TOTAL-1)
                    y <= 0;
                else
                    y <= y + 1;
            end else begin
                x <= x + 1;
            end
        end
    end

    assign hsync = (x >= H_ACTIVE + H_FP) && (x < H_ACTIVE + H_FP + H_SYNC);
    assign vsync = (y >= V_ACTIVE + V_FP) && (y < V_ACTIVE + V_FP + V_SYNC);
    assign de    = (x < H_ACTIVE) && (y < V_ACTIVE);

endmodule
