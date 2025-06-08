module top#(
    parameter pmod_num = 1, 
    parameter pmod_io_num = 1 * 8 - 1,
    parameter frequency = 50_000_000
)
(
    input clk,
    input key,  // active-high pushbutton

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
    .FILE_NAME_LEN(9),
    .FILE_NAME("image.bmp"),
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

// framebuffer for BMP image
localparam H_ACTIVE = 640;
localparam V_ACTIVE = 480;
localparam FRAME_PIXELS = H_ACTIVE*V_ACTIVE;
localparam ADDR_WIDTH = 19;

reg [23:0] framebuffer [0:FRAME_PIXELS-1];
reg [ADDR_WIDTH-1:0] fb_wr_addr = 0;
reg [1:0] byte_phase = 0;
reg [23:0] pix_buf = 0;
reg [31:0] byte_index = 0;

always @(posedge clk or posedge key_clean) begin
    if (key_clean) begin
        fb_wr_addr <= 0;
        byte_phase <= 0;
        byte_index <= 0;
        status <= STATUS_INIT;
    end else begin
        if (card_stat == 4'd8)
            status <= STATUS_SD_OK;
        if (file_found)
            status <= STATUS_FILE_OK;

        if (file_found && outen && fb_wr_addr < FRAME_PIXELS) begin
            status <= STATUS_LOADING;
            byte_index <= byte_index + 1;
            if (byte_index >= 54) begin
                case(byte_phase)
                    2'd0: pix_buf[7:0]   <= outbyte;       // B
                    2'd1: pix_buf[15:8]  <= outbyte;       // G
                    2'd2: begin
                        pix_buf[23:16] <= outbyte;          // R
                        framebuffer[fb_wr_addr] <= pix_buf;
                        fb_wr_addr <= fb_wr_addr + 1;
                    end
                endcase
                byte_phase <= byte_phase + 1;
                if (byte_phase == 2)
                    byte_phase <= 0;
                if (fb_wr_addr == FRAME_PIXELS-1)
                    status <= STATUS_DISPLAY;
            end
        end
    end
end
// 7-segment status codes
// 0 : Initializing
// 1 : SD card ready
// 2 : File found
// 3 : Loading image
// 4 : Displaying image
// E : Error
localparam STATUS_INIT    = 4'h0;
localparam STATUS_SD_OK   = 4'h1;
localparam STATUS_FILE_OK = 4'h2;
localparam STATUS_LOADING = 4'h3;
localparam STATUS_DISPLAY = 4'h4;
localparam STATUS_ERR     = 4'hE;

reg [3:0] status = STATUS_INIT;
reg [3:0] digit_high = 4'h0;
reg [3:0] digit_low  = STATUS_INIT;

always @(posedge clk) begin
    digit_high <= 4'h0;
    digit_low  <= status;
end

// Generate 25 MHz pixel clock from the 50 MHz input
reg pix_clk = 0;
always @(posedge clk) pix_clk <= ~pix_clk;

// PLL to create the 250 MHz TMDS bit clock
wire tmds_clk;
wire pll_lock;
gowin_pll_50m_250m pll_video(
    .clkout(tmds_clk),
    .lock(pll_lock),
    .clkin(clk)
);

// Video timing generator
wire       v_hsync, v_vsync, v_de;
wire [11:0] px;
wire [11:0] py;
video_timing timing_inst(
    .clk(pix_clk),
    .rst(key_clean),
    .x(px),
    .y(py),
    .hsync(v_hsync),
    .vsync(v_vsync),
    .de(v_de)
);

// Display a constant red color on every pixel
// The framebuffer and SD logic remain but are ignored
// for the final video output.
wire [7:0] v_r = 8'hFF;
wire [7:0] v_g = 8'h00;
wire [7:0] v_b = 8'h00;

// TMDS transmitter
wire tmds_clk_p, tmds_clk_n;
wire tmds_red_p, tmds_red_n;
wire tmds_green_p, tmds_green_n;
wire tmds_blue_p, tmds_blue_n;
hdmi_tx tx(
    .pix_clk(pix_clk),
    .tmds_clk(tmds_clk),
    .rst(key_clean),
    .red(v_r),
    .green(v_g),
    .blue(v_b),
    .hsync(v_hsync),
    .vsync(v_vsync),
    .de(v_de),
    .tmds_clk_p(tmds_clk_p),
    .tmds_clk_n(tmds_clk_n),
    .tmds_red_p(tmds_red_p),
    .tmds_red_n(tmds_red_n),
    .tmds_green_p(tmds_green_p),
    .tmds_green_n(tmds_green_n),
    .tmds_blue_p(tmds_blue_p),
    .tmds_blue_n(tmds_blue_n)
);

// Map TMDS outputs to PMOD pins
assign pmod_io[0] = tmds_clk_p;
assign pmod_io[1] = tmds_clk_n;
assign pmod_io[2] = tmds_red_p;
assign pmod_io[3] = tmds_red_n;
assign pmod_io[4] = tmds_green_p;
assign pmod_io[5] = tmds_green_n;
assign pmod_io[6] = tmds_blue_p;
assign pmod_io[7] = tmds_blue_n;

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
