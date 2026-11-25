// FILE PURPOSE: decides which way to remove when a set is full (LRU = Least Recently Used).
// Start of the module.
module lru_unit(
    // Clock and reset inputs.
    input  wire       clk, reset,
    // Which of the 16 sets we are using.
    input  wire [3:0] set_index,
    // Whether way 0 and way 1 of this set hold real data.
    input  wire       valid0, valid1,
    // touch = "a way was just used". touched_way = which one (0 or 1).
    input  wire       touch, touched_way,
    // Output: the way that should be removed (the "victim").
    output wire       victim_way
// End of the list of inputs and outputs.
);
    // 16 bits, one per set. Each bit holds the number of that set's least recently used way.
    reg [15:0] least_recent_way;

    // Choose the victim. "a ? b : c" means: if a is true use b, else c. If way 0 is empty, pick 0.
    assign victim_way = !valid0 ? 1'b0 :
                        // Else if way 1 is empty, pick 1. Else (both full) pick the least recently used way.
                        !valid1 ? 1'b1 : least_recent_way[set_index];

    // Do the following at every rising clock edge.
    always @(posedge clk) begin
        // If reset is on...
        if (reset)
            // ...clear all 16 bits to 0.
            least_recent_way <= 0;
        // Otherwise, if a way was just used...
        else if (touch)
            // ...the OTHER way is now the older one, so store the opposite of the used way (~ means NOT).
            least_recent_way[set_index] <= ~touched_way;
    // End of the clocked block.
    end
// End of the module.
endmodule
