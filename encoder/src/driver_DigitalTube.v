module driver_DigitalTubeHexHex #(
    parameter P_CNT = 300_000  // Scan period (adjust based on clk frequency)
)(
    input           i_clk,
    input           i_rst,
    input   [3:0]   i_hexHigh,
    input   [3:0]   i_hexLow,
    output  [6:0]   o_digitalTube,  // segments A-G (active-low)
    output          o_sel           // digit select
);

    // Hex-to-7-segment decoder (active-low)
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
            default: hex_to_seg = 7'b1111111; // blank
        endcase
    endfunction

    reg [6:0] r_seg = 7'b1111111;
    reg       r_sel = 1'b0;
    reg [23:0] r_cnt = 0;

    assign o_digitalTube = r_seg;
    assign o_sel = r_sel;

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            r_cnt <= 0;
            r_sel <= 0;
        end else if (r_cnt >= P_CNT) begin
            r_cnt <= 0;
            r_sel <= ~r_sel;
        end else begin
            r_cnt <= r_cnt + 1;
        end
    end

    always @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
        r_seg <= 7'b1111111;
    end else begin
        // Always update based on current digit select line
        r_seg <= r_sel ? hex_to_seg(i_hexHigh) : hex_to_seg(i_hexLow);
    end
end


endmodule
