// Baseline control FSM. EXECUTE handles ordinary single-cycle instructions;
// LOAD_WAIT commits synchronous BRAM output; HALTED parks execution. Branch
// targets are selected early enough to be fetched on the redirecting edge.
module baseline_control_unit (
    input wire clk,
    input wire rst,
    input wire mem_read,
    input wire halt_instruction,
    output wire execute_instruction,
    output wire load_issue,
    output wire load_commit,
    output wire pc_write,
    output wire rom_enable,
    output wire halted
);
    localparam [1:0] EXECUTE   = 2'b00;
    localparam [1:0] LOAD_WAIT = 2'b01;
    localparam [1:0] HALTED    = 2'b10;
    reg [1:0] state;

    assign execute_instruction = (state == EXECUTE);
    assign load_issue = execute_instruction & mem_read;
    assign load_commit = (state == LOAD_WAIT);
    assign pc_write = (execute_instruction & ~halt_instruction & ~mem_read) |
                      load_commit;
    assign rom_enable = rst | ((state != HALTED) &
                       ~(execute_instruction & (halt_instruction | mem_read)));
    assign halted = (state == HALTED);

    always @(posedge clk) begin
        if (rst) begin
            state <= EXECUTE;
        end else begin
            case (state)
                EXECUTE: begin
                    if (halt_instruction)
                        state <= HALTED;
                    else if (mem_read)
                        state <= LOAD_WAIT;
                end
                LOAD_WAIT: state <= EXECUTE;
                HALTED:    state <= HALTED;
                default:   state <= EXECUTE;
            endcase
        end
    end
endmodule
