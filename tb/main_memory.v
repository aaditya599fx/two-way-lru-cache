// FILE PURPOSE: a pretend main memory, used only in simulation. It is slow on purpose.
// `timescale: time is counted in 1ns steps, with 1ps accuracy.
`timescale 1ns/1ps
// Start of the memory module.
module main_memory(
    // Inputs: clock, reset, "a command is present", and write (1) or read (0).
    input  wire        clk, reset, valid, write_en,
    // Inputs: the address, and the data to write.
    input  wire [31:0] address, write_data,
    // Output: "ready" means the command is completing now.
    output wire        ready,
    // Output: the data read from memory.
    output wire [31:0] read_data
// End of the list of inputs and outputs.
);
    // The memory has 1024 words (1024 x 4 bytes = 4 KiB).
    localparam WORDS = 1024;
    // The storage for all those words.
    reg [31:0] words [0:WORDS-1];
    // A small counter used to create the delay.
    reg [1:0] delay_count;
    // Which word is wanted: address bits 11 to 2 (this is the address divided by 4).
    wire [9:0] word_index = address[11:2];
    // A loop counter.
    integer i;

    // This block runs only once, when the simulation starts.
    initial begin
        // Go through every word...
        for (i = 0; i < WORDS; i = i + 1)
            // ...and give it a known starting value: CAFE0000 + its position. This makes checking easy.
            words[i] = 32'hCAFE0000 + i;
    // End of the start-up block.
    end

    // Ready only after the counter reaches 2, which is the third clock edge of a command.
    assign ready = !reset && valid && delay_count == 2;
    // Always show the word at the requested position.
    assign read_data = words[word_index];

    // Do the following at every rising clock edge.
    always @(posedge clk) begin
        // If reset is on, or there is no command...
        if (reset || !valid) begin
            // ...keep the delay counter at 0.
            delay_count <= 0;
        // Otherwise a command is running.
        end else begin
            // Check the address is inside 4 KiB and is a multiple of 4.
            if (address >= 4096 || address[1:0] != 0)
                // If not, stop the simulation with an error message.
                $fatal(1, "Out-of-range or unaligned memory address %h", address);
            // If the waiting time is over...
            if (ready) begin
                // ...and it is a write command...
                if (write_en)
                    // ...save the data into memory.
                    words[word_index] <= write_data;
                // Reset the counter for the next command.
                delay_count <= 0;
            // If not ready yet...
            end else
                // ...count one more clock tick.
                delay_count <= delay_count + 1'b1;
        // End of the "command is running" part.
        end
    // End of the clocked block.
    end
// End of the module.
endmodule
