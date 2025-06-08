// Simple DVI PMOD output with 640x480 timing
// Generates TMDS pairs for Digilent DVI PMOD
// Video pattern shows two hexadecimal digits scaled on screen

module dvi_pmod #(
    parameter H_ACTIVE = 640,
    parameter H_FP     = 16,
    parameter H_SYNC   = 96,
    parameter H_BP     = 48,
    parameter V_ACTIVE = 480,
    parameter V_FP     = 10,
    parameter V_SYNC   = 2,
    parameter V_BP     = 33
)(
    input        clk,       // 50 MHz system clock
    input        rst,
    input  [3:0] hex_high,
    input  [3:0] hex_low,
    output [7:0] tmds
);

    // Generate 25 MHz pixel clock
    reg pix_clk = 0;
    always @(posedge clk) begin
        pix_clk <= ~pix_clk;
    end

    localparam H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;
    localparam V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP;

    reg [11:0] h_cnt = 0;
    reg [11:0] v_cnt = 0;

    always @(posedge pix_clk or posedge rst) begin
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

    wire h_active = h_cnt < H_ACTIVE;
    wire v_active = v_cnt < V_ACTIVE;
    wire de = h_active & v_active;
    wire hsync = (h_cnt >= H_ACTIVE + H_FP) && (h_cnt < H_ACTIVE + H_FP + H_SYNC);
    wire vsync = (v_cnt >= V_ACTIVE + V_FP) && (v_cnt < V_ACTIVE + V_FP + V_SYNC);

    // 7-segment decoder copied from display driver (active low)
    function [6:0] hex_to_seg;
        input [3:0] hex;
        case (hex)
            4'h0: hex_to_seg = 7'b0000001;
            4'h1: hex_to_seg = 7'b1001111;
            4'h2: hex_to_seg = 7'b0010010;
            4'h3: hex_to_seg = 7'b0000110;
            4'h4: hex_to_seg = 7'b1001100;
            4'h5: hex_to_seg = 7'b0100100;
            4'h6: hex_to_seg = 7'b0100000;
            4'h7: hex_to_seg = 7'b0001111;
            4'h8: hex_to_seg = 7'b0000000;
            4'h9: hex_to_seg = 7'b0000100;
            4'hA: hex_to_seg = 7'b0001000;
            4'hB: hex_to_seg = 7'b1100000;
            4'hC: hex_to_seg = 7'b0110001;
            4'hD: hex_to_seg = 7'b1000010;
            4'hE: hex_to_seg = 7'b0110000;
            4'hF: hex_to_seg = 7'b0111000;
            default: hex_to_seg = 7'b1111111;
        endcase
    endfunction

    wire [6:0] seg_high = ~hex_to_seg(hex_high); // active high
    wire [6:0] seg_low  = ~hex_to_seg(hex_low);

    // Digit placement and segment drawing (very coarse)
    localparam DIGIT_W = 80;
    localparam DIGIT_H = 140;
    localparam SEG_T   = 20;   // segment thickness
    localparam X_OFF   = 100;
    localparam Y_OFF   = 60;

    // Determine if current pixel is part of a segment for selected digit
    function pixel_on;
        input [6:0] segs;
        input [10:0] x;
        input [10:0] y;
        reg on;
        begin
            on = 0;
            // Horizontal segments
            if (y < SEG_T && segs[0]) on = 1; // top
            if (y >= DIGIT_H/2-SEG_T/2 && y < DIGIT_H/2+SEG_T/2 && segs[6]) on = 1; // middle
            if (y >= DIGIT_H-SEG_T && segs[3]) on = 1; // bottom
            // Vertical segments
            if (x < SEG_T && y < DIGIT_H/2 && segs[5]) on = 1; // top-left
            if (x < SEG_T && y >= DIGIT_H/2 && segs[4]) on = 1; // bottom-left
            if (x >= DIGIT_W-SEG_T && y < DIGIT_H/2 && segs[1]) on = 1; // top-right
            if (x >= DIGIT_W-SEG_T && y >= DIGIT_H/2 && segs[2]) on = 1; // bottom-right
            pixel_on = on;
        end
    endfunction

    reg [7:0] red = 0, green = 0, blue = 0;

    always @(posedge pix_clk) begin
        red   <= 0;
        green <= 0;
        blue  <= 0;
        if (de) begin
            if (h_cnt >= X_OFF && h_cnt < X_OFF + DIGIT_W &&
                v_cnt >= Y_OFF && v_cnt < Y_OFF + DIGIT_H) begin
                if (pixel_on(seg_high, h_cnt-X_OFF, v_cnt-Y_OFF)) begin
                    red <= 8'hff; green <= 8'hff; blue <= 8'hff;
                end
            end else if (h_cnt >= X_OFF + DIGIT_W + SEG_T &&
                         h_cnt < X_OFF + 2*DIGIT_W + SEG_T &&
                         v_cnt >= Y_OFF && v_cnt < Y_OFF + DIGIT_H) begin
                if (pixel_on(seg_low, h_cnt-(X_OFF + DIGIT_W + SEG_T), v_cnt-Y_OFF)) begin
                    red <= 8'hff; green <= 8'hff; blue <= 8'hff;
                end
            end
        end
    end

    // Simplified TMDS encoding (not optimized)
    function [9:0] tmds_encode;
        input [7:0] d;
        input c0, c1, de_in;
        reg [3:0] n1d;
        reg [3:0] n1q;
        reg [8:0] q_m;
        reg [9:0] enc;
        integer i;
        begin
            n1d = d[0]+d[1]+d[2]+d[3]+d[4]+d[5]+d[6]+d[7];
            if (n1d > 4 || (n1d==4 && d[0]==0)) begin
                q_m[0] = d[0];
                for (i=1;i<8;i=i+1) q_m[i] = q_m[i-1] ^~ d[i];
                q_m[8] = 0;
            end else begin
                q_m[0] = d[0];
                for (i=1;i<8;i=i+1) q_m[i] = q_m[i-1] ^ d[i];
                q_m[8] = 1;
            end
            n1q = q_m[0]+q_m[1]+q_m[2]+q_m[3]+q_m[4]+q_m[5]+q_m[6]+q_m[7];
            if (!de_in) begin
                case ({c1,c0})
                    2'b00: enc = 10'b1101010100;
                    2'b01: enc = 10'b0010101011;
                    2'b10: enc = 10'b0101010100;
                    2'b11: enc = 10'b1010101011;
                endcase
            end else if ((n1q > 4) || (n1q == 4 && q_m[8] == 0)) begin
                enc = {1'b1, q_m[8], ~q_m[7:0]};
            end else begin
                enc = {1'b0, q_m[8], q_m[7:0]};
            end
            tmds_encode = enc;
        end
    endfunction

    reg [9:0] tmds_red, tmds_green, tmds_blue, tmds_clk;

    always @(posedge pix_clk) begin
        tmds_red   <= tmds_encode(red, 0, 0, de);
        tmds_green <= tmds_encode(green, 0, 0, de);
        tmds_blue  <= tmds_encode(blue, hsync, vsync, de);
        tmds_clk   <= 10'b0000011111; // simple clock pattern
    end

    assign tmds = {tmds_clk[0], tmds_clk[5], tmds_red[0], tmds_red[5], tmds_green[0], tmds_green[5], tmds_blue[0], tmds_blue[5]};

endmodule
