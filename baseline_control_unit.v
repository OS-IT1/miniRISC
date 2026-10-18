// Baseline control FSM. EXECUTE handles ordinary single-cycle instructions;
// LOAD_WAIT commits synchronous BRAM output; HALTED parks execution. Branch
// targets are selected early enough to be fetched on the redirecting edge.
module baseline_control_unit (
    input wire clk,
    input wire rst,
    input wire mem_read,
    input wire halt_instruction,
    input wire mul_instruction,
    input wire multiplier_done,
    output wire execute_instruction,
    output wire mul_start,
    output wire mul_wait,
    output wire mul_commit,
    output wire load_issue,
    output wire load_commit,
    output wire pc_write,
    output wire rom_enable,
    output wire halted
);
    localparam [1:0] EXECUTE   = 2'b00;
    localparam [1:0] LOAD_WAIT = 2'b01;
    localparam [2:0] HALTED      = 3'b010;
    localparam [2:0] MUL_WAIT    = 3'b011;
    reg [2:0] state;

    assign execute_instruction = (state == EXECUTE);
    assign load_issue = execute_instruction & mem_read;
    assign load_commit = (state == LOAD_WAIT);
    assign mul_start = execute_instruction & mul_instruction;
    assign mul_wait = (state == MUL_WAIT);
    assign mul_commit = mul_wait & multiplier_done;
    assign pc_write = (execute_instruction & ~halt_instruction & ~mem_read & ~mul_instruction) |
                      load_commit | mul_commit;
    assign rom_enable = rst | ((state != HALTED) &
                       ~(execute_instruction & (halt_instruction | mem_read | mul_instruction)) &
                       ~(mul_wait & ~multiplier_done));
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
                    else if (mul_instruction)
                        state <= MUL_WAIT;
                end
                LOAD_WAIT: state <= EXECUTE;
                MUL_WAIT: if (multiplier_done) state <= EXECUTE;
                HALTED:    state <= HALTED;
                default:   state <= EXECUTE;
            endcase
        end
    end
endmodule
