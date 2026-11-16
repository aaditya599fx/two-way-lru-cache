`timescale 1ns/1ps
module main_memory(
    input  wire        clk, reset, valid, write_en,
    input  wire [31:0] address, write_data,
    output wire        ready,
    output wire [31:0] read_data
);
    localparam WORDS = 1024;
    reg [31:0] words [0:WORDS-1];
    reg [1:0] delay_count;
    wire [9:0] word_index = address[11:2];
    integer i;

    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            words[i] = 32'hCAFE0000 + i;
    end

    assign ready = !reset && valid && delay_count == 2;
    assign read_data = words[word_index];

    always @(posedge clk) begin
        if (reset || !valid) begin
            delay_count <= 0;
        end else begin
            if (address >= 4096 || address[1:0] != 0)
                $fatal(1, "Out-of-range or unaligned memory address %h", address);
            if (ready) begin
                if (write_en)
                    words[word_index] <= write_data;
                delay_count <= 0;
            end else
                delay_count <= delay_count + 1'b1;
        end
    end
endmodule
