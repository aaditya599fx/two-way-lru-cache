module lru_unit(
    input  wire       clk, reset,
    input  wire [3:0] set_index,
    input  wire       valid0, valid1,
    input  wire       touch, touched_way,
    output wire       victim_way
);
    reg [15:0] least_recent_way;

    assign victim_way = !valid0 ? 1'b0 :
                        !valid1 ? 1'b1 : least_recent_way[set_index];

    always @(posedge clk) begin
        if (reset)
            least_recent_way <= 0;
        else if (touch)
            least_recent_way[set_index] <= ~touched_way;
    end
endmodule
