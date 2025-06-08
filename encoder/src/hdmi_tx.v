// Simple HDMI transmitter generating 640x480 @ 60Hz
// This module encodes RGB pixels into TMDS and serializes them
// using a 10x pixel clock. It drives four single-ended signals
// (positive sides of the differential pairs on the DVI PMOD).
// The negative pins should be connected to the complementary outputs
// or to resistors for proper TMDS signalling.

module hdmi_tx (
    input        pix_clk,   // 25 MHz pixel clock
    input        tmds_clk,  // 250 MHz serial clock
    input        rst,
    input  [7:0] red,
    input  [7:0] green,
    input  [7:0] blue,
    input        hsync,
    input        vsync,
    input        de,
    output       tmds_clk_p,
    output       tmds_red_p,
    output       tmds_green_p,
    output       tmds_blue_p
);

    // TMDS encoding function (from simplified encoder in dvi_pmod)
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

    reg [9:0] tmds_red, tmds_green, tmds_blue, tmds_clock;

    always @(posedge pix_clk) begin
        tmds_red   <= tmds_encode(red, 0, 0, de);
        tmds_green <= tmds_encode(green, 0, 0, de);
        tmds_blue  <= tmds_encode(blue, hsync, vsync, de);
        tmds_clock <= 10'b0000011111; // clock pattern
    end

    reg [9:0] shift_red   = 0;
    reg [9:0] shift_green = 0;
    reg [9:0] shift_blue  = 0;
    reg [9:0] shift_clock = 0;
    reg [3:0] shift_cnt   = 0;

    always @(posedge tmds_clk or posedge rst) begin
        if (rst) begin
            shift_cnt   <= 0;
            shift_red   <= 0;
            shift_green <= 0;
            shift_blue  <= 0;
            shift_clock <= 0;
        end else begin
            if (shift_cnt == 0) begin
                shift_cnt   <= 9;
                shift_red   <= tmds_red;
                shift_green <= tmds_green;
                shift_blue  <= tmds_blue;
                shift_clock <= tmds_clock;
            end else begin
                shift_cnt   <= shift_cnt - 1;
                shift_red   <= {1'b0, shift_red[9:1]};
                shift_green <= {1'b0, shift_green[9:1]};
                shift_blue  <= {1'b0, shift_blue[9:1]};
                shift_clock <= {1'b0, shift_clock[9:1]};
            end
        end
    end

    assign tmds_red_p   = shift_red[0];
    assign tmds_green_p = shift_green[0];
    assign tmds_blue_p  = shift_blue[0];
    assign tmds_clk_p   = shift_clock[0];

endmodule
