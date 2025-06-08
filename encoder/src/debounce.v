module debounce #(parameter DELAY = 20_000) (
    input clk,
    input noisy,
    output reg clean = 0
);
    reg [15:0] count = 0;
    reg prev = 0;

    always @(posedge clk) begin
        if (noisy != prev) begin
            count <= 0;
            prev <= noisy;
        end else if (count < DELAY) begin
            count <= count + 1;
        end else begin
            clean <= prev;
        end
    end
endmodule
