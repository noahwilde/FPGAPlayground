module top#(
    parameter pmod_num = 1, 
    parameter pmod_io_num = 1 * 8 - 1,
    parameter frequency = 50_000_000
)
(
    input clk,
    input key,  // active-high pushbutton
    input key2,

    output led_done,   // onboard LED for file_found
    output led_ready,  // onboard LED for outen
    output wire sdclk,
    inout wire sdcmd,
    input wire sddat0,
    inout wire sddat1,
    inout wire sddat2,
    inout wire sddat3,
    inout [pmod_io_num:0] pmod_io,

    output wire [6:0] o_digitalTube,
    output wire       o_sel

);

// Debounced key
wire key_clean;
debounce db(.clk(clk), .noisy(key), .clean(key_clean));

// Debounce for key2
wire key2_clean;
debounce db2(.clk(clk), .noisy(key2), .clean(key2_clean));

// Force SD DAT1~3 high to stay in SD bus mode
assign sddat1 = 1'b1;
assign sddat2 = 1'b1;
assign sddat3 = 1'b1;

// File reader outputs
wire [3:0] card_stat;
wire [1:0] card_type;
wire [1:0] filesystem_type;
wire file_found;
wire outen;
wire [7:0] outbyte;

sd_file_reader #(
    .FILE_NAME_LEN(7),
    .FILE_NAME("hex.txt"),
    .CLK_DIV(3'd2),
    .SIMULATE(0)
) sd_inst (
    .rstn(~key_clean),
    .clk(clk),
    .sdclk(sdclk),
    .sdcmd(sdcmd),
    .sddat0(sddat0),
    .card_stat(card_stat),
    .card_type(card_type),
    .filesystem_type(filesystem_type),
    .file_found(file_found),
    .outen(outen),
    .outbyte(outbyte)
);
// Displayed hex digits for the two-digit 7-segment module
reg [3:0] digit_high = 4'h0;
reg [3:0] digit_low  = 4'h0;

reg [8:0] byte_index = 0;
reg [8:0] max_index = 0;
reg [7:0] byte_buffer [0:511];

reg key2_prev = 0;
reg outen_prev = 0;
reg shown_first_byte = 0;

always @(posedge clk) begin
    // Rising edge of outen (new byte available)
    outen_prev <= outen;
    if (outen && ~outen_prev) begin
        byte_buffer[max_index] <= outbyte;
        max_index <= max_index + 1;

        if (~shown_first_byte) begin
            digit_high <= outbyte[3:0]; 
            digit_low  <= outbyte[7:4]; 
            shown_first_byte <= 1;
            byte_index <= 1;
        end

    end

    // Rising edge of key2 (advance display)
    key2_prev <= key2_clean;
    if (key2_clean && ~key2_prev && byte_index < max_index) begin
        digit_high <= byte_buffer[byte_index][3:0];
        digit_low  <= byte_buffer[byte_index][7:4];
        byte_index <= byte_index + 1;
    end

    // Reset when key is held
    if (key_clean) begin
        byte_index <= 0;
        max_index <= 0;
        digit_high <= 4'h0;
        digit_low  <= 4'h0;
        shown_first_byte <= 0;  
    end
end

// Status LEDs on PMOD0
assign pmod_io[0] = ~card_stat[0];
assign pmod_io[1] = ~card_stat[1];
assign pmod_io[2] = ~card_stat[2];
assign pmod_io[3] = ~card_stat[3];
assign pmod_io[4] = ~card_type[0];
assign pmod_io[5] = ~card_type[1];
assign pmod_io[6] = ~filesystem_type[0];
assign pmod_io[7] = ~filesystem_type[1];

// LED indicators
assign led_done  = file_found;
assign led_ready = outen;

driver_DigitalTubeHexHex display_driver (
    .i_clk(clk),
    .i_rst(key_clean),  // Reset only when the key is actively pressed
    .i_hexHigh(digit_high),
    .i_hexLow(digit_low),
    .o_digitalTube(o_digitalTube),
    .o_sel(o_sel)
);


endmodule
