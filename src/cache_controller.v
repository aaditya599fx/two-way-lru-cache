module cache_controller #(parameter INDEX_BITS = 4)(
    input  wire        clk, reset,
    input  wire        req_valid, req_write,
    input  wire [31:0] req_addr, req_wdata,
    output wire        req_ready,
    output wire        resp_valid,
    output reg         resp_hit, resp_error,
    output reg  [31:0] resp_rdata,
    input  wire        hit0, hit1, victim_way, victim_dirty,
    input  wire [31:0] hit_data, victim_data,
    input  wire [29-INDEX_BITS:0] victim_tag,
    output reg  [31:0] lookup_addr,
    output wire        line_write, line_way, line_dirty, touch,
    output wire [31:0] line_data,
    output wire        mem_valid, mem_write,
    output wire [31:0] mem_addr, mem_wdata,
    input  wire        mem_ready,
    input  wire [31:0] mem_rdata
);
    localparam [2:0] IDLE = 0, TAG_COMPARE = 1, WRITEBACK = 2,
                     REFILL = 3, DONE = 4;
    reg [2:0] state;
    reg write_request, refill_way;
    reg [31:0] request_data;
    wire hit = hit0 || hit1;
    wire aligned = lookup_addr[1:0] == 2'b00;
    wire hit_access = state == TAG_COMPARE && aligned && hit;
    wire fill = state == REFILL && mem_ready;

    assign req_ready  = !reset && state == IDLE;
    assign resp_valid = !reset && state == DONE;
    assign line_write = !reset && (fill || (hit_access && write_request));
    assign touch      = !reset && (fill || hit_access);
    assign line_way   = state == REFILL ? refill_way : hit1;
    assign line_dirty = write_request;
    assign line_data  = write_request ? request_data : mem_rdata;
    assign mem_valid  = !reset && (state == WRITEBACK || state == REFILL);
    assign mem_write  = state == WRITEBACK;
    assign mem_addr   = mem_write ? {victim_tag, lookup_addr[INDEX_BITS+1:2], 2'b00} :
                                     {lookup_addr[31:2], 2'b00};
    assign mem_wdata  = victim_data;

    always @(posedge clk) begin
        if (reset) begin
            state         <= IDLE;
            lookup_addr   <= 0;
            request_data  <= 0;
            write_request <= 0;
            refill_way    <= 0;
            resp_hit      <= 0;
            resp_error    <= 0;
            resp_rdata    <= 0;
        end else begin
            case (state)
                IDLE: if (req_valid) begin
                    lookup_addr   <= req_addr;
                    request_data  <= req_wdata;
                    write_request <= req_write;
                    resp_hit      <= 0;
                    resp_error    <= 0;
                    resp_rdata    <= 0;
                    state         <= TAG_COMPARE;
                end
                TAG_COMPARE: begin
                    if (!aligned) begin
                        resp_error <= 1;
                        state <= DONE;
                    end else if (hit) begin
                        resp_hit   <= 1;
                        resp_rdata <= write_request ? request_data : hit_data;
                        state      <= DONE;
                    end else begin
                        refill_way <= victim_way;
                        state      <= victim_dirty ? WRITEBACK : REFILL;
                    end
                end
                WRITEBACK: if (mem_ready)
                    state <= REFILL;
                REFILL: if (mem_ready) begin
                    resp_rdata <= line_data;
                    state      <= DONE;
                end
                DONE: state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
