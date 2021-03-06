
//# Pipeline Half-Buffer

// A single pipeline register with ready/valid handshakes.  Decouples the
// input and ouput handshakes (no combinational path), but does not allow
// concurrent read/write like a full [Pipeline Skid
// Buffer](./Pipeline_Skid_Buffer.html). The half-buffer must be read out
// before you can write into it again, halving the maximum bandwidth.

// However, using a half-buffer can improve the throughput of a long-running
// module with ready/valid handshakes, where the module input will not accept
// new data until the module output is read out, and it takes multiple cycles
// to compute a result. With a half-buffer, the module can immediately dump
// its output into the half-buffer and then accept new input data, overlapping
// another computation with the wait time until the final destination reads
// out the half-buffer.

`default_nettype none

module Pipeline_Half_Buffer
#(
    parameter WORD_WIDTH    = 0,
    parameter RESET_VALUE   = 0
)
(
    input  wire                  clock,
    input  wire                  clear,

    input  wire                  data_in_valid,
    output reg                   data_in_ready,
    input  wire [WORD_WIDTH-1:0] data_in,

    output reg                   data_out_valid,
    input  wire                  data_out_ready,
    output wire [WORD_WIDTH-1:0] data_out
);

// Storage for the data

    reg half_buffer_load = 1'b0;

    Register
    #(
        .WORD_WIDTH     (WORD_WIDTH),
        .RESET_VALUE    (RESET_VALUE)
    )
    half_buffer
    (
        .clock          (clock),
        .clock_enable   (half_buffer_load),
        .clear          (clear),
        .data_in        (data_in),
        .data_out       (data_out)
    );

// And an empty/full bit associated with the data storage.

    reg  set_to_empty = 1'b0;
    reg  set_to_full  = 1'b0;
    wire buffer_full;

    Register
    #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (1'b0)
    )
    empty_full
    (
        .clock          (clock),
        .clock_enable   (set_to_full),
        .clear          (set_to_empty),
        .data_in        (1'b1),
        .data_out       (buffer_full)
    );

// Then, from the state of the empty/full bit and the signals local only to
// each handshake (no path between them), determine when data can transfer.
// Note that we must be empty before we can `set_to_full`. Anything else
// creates a combinational path from the input handshake to the output
// handshake.

    always @(*) begin
        set_to_empty     = (data_out_valid == 1'b1) && (data_out_ready == 1'b1);
        set_to_full      = (data_in_valid  == 1'b1) && (buffer_full    == 1'b0);
        half_buffer_load = (set_to_full == 1'b1);
    end

    always @(*) begin
        data_in_ready    = (buffer_full == 1'b0);
        data_out_valid   = (buffer_full == 1'b1);
    end

endmodule

