#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <unordered_map>
#include <algorithm>
#include <cctype>
#include <bitset>

using namespace std;

// ISA Definition (Now in lowercase)
struct InstrFmt {
    string opcode;
    string type;
};

unordered_map<string, InstrFmt> ISA = {
    {"add",  {"00000", "R"}},
    {"sub",  {"00001", "R"}},
    {"and",  {"00010", "R"}},
    {"or",   {"00011", "R"}},
    {"xor",  {"00100", "R"}},
    {"nor",  {"00101", "R"}},
    {"not",  {"00110", "R_1_reg"}}, 
    {"sll",  {"00111", "I"}},
    {"srl",  {"01000", "I"}},
    {"sra",  {"01001", "R"}},
    {"sla",  {"01010", "R"}},
    {"slt",  {"01011", "R"}},
    {"sgt",  {"01100", "R"}},
    {"mul",  {"01101", "R"}},
    {"addi", {"01110", "I"}},
    {"subi", {"01111", "I"}},
    {"mov",  {"10000", "I_MOV"}},
    {"lui",  {"10001", "I_LUI"}},
    {"ld",   {"10010", "M"}},
    {"st",   {"10011", "M"}},
    {"beq",  {"10100", "B"}},
    {"bne",  {"10101", "B"}},
    {"j",    {"10110", "J"}},
    {"jr",   {"10111", "JR"}},
    {"nop",  {"11000", "SYS"}},
    {"halt", {"11001", "SYS"}}
};

// Convert string to lowercase
string to_lower(string s) {
    transform(s.begin(), s.end(), s.begin(), ::tolower);
    return s;
}

// Helper to convert integer to binary string with fixed width (handles two's complement)
string to_bin(long long val, int bits) {
    string res = "";
    unsigned long long mask = (1ULL << bits) - 1;
    unsigned long long uval = val & mask;
    for (int i = bits - 1; i >= 0; --i) {
        res += ((uval >> i) & 1) ? '1' : '0';
    }
    return res;
}

// Parse register string (e.g. "r1", "1") to integer
int parse_reg(string reg_str) {
    reg_str = to_lower(reg_str);
    reg_str.erase(remove_if(reg_str.begin(), reg_str.end(), [](char c){ return c == 'r'; }), reg_str.end());
    return stoi(reg_str);
}

// Parse integer or hex string
long long parse_imm(string imm_str) {
    return stoll(imm_str, nullptr, 0); // 0 allows auto-detect of 0x for hex
}

// Trim whitespace from string
string trim(const string& str) {
    size_t first = str.find_first_not_of(" \t\n\r");
    if (string::npos == first) return "";
    size_t last = str.find_last_not_of(" \t\n\r");
    return str.substr(first, (last - first + 1));
}

int main() {
    // Example input in fully small case
    // string assembly_input = R"(
    //     start:  addi r1, r0, 5
    //             addi r2, r0, 10
    //     loop:   add  r3, r3, r1
    //             subi r2, r2, 1
    //             bne  r2, r0, loop   // branch backwards to loop
    //             j    end            // forward jump to end
    //             nop
    //     end:    halt
    // )";

    ifstream file("input.txt");

    if (!file) {
        cerr << "Error opening file\n";
        return 1;
    }

    string assembly_input((istreambuf_iterator<char>(file)),
                    istreambuf_iterator<char>());

    stringstream asm_stream(assembly_input);
    string line;
    
    unordered_map<string, int> labels;
    vector<string> instructions;
    
    // --- PASS 1: Resolve Labels ---
    int current_addr = 0;
    while (getline(asm_stream, line)) {
        // Strip comments
        size_t comment_pos = line.find("//");
        if (comment_pos != string::npos) {
            line = line.substr(0, comment_pos);
        }
        
        line = trim(line);
        if (line.empty()) continue;
        
        // Extract label
        size_t colon_pos = line.find(':');
        if (colon_pos != string::npos) {
            // Store labels as lowercase to ensure case-insensitive matching
            string label = to_lower(trim(line.substr(0, colon_pos)));
            labels[label] = current_addr;
            line = trim(line.substr(colon_pos + 1));
        }
        
        if (!line.empty()) {
            instructions.push_back(line);
            current_addr++;
        }
    }

    // --- PASS 2: Generate Machine Code ---
    vector<string> binary_out;
    for (int pc = 0; pc < instructions.size(); ++pc) {
        string inst = instructions[pc];
        
        // Standardize separators (commas and parentheses to space)
        replace(inst.begin(), inst.end(), ',', ' ');
        replace(inst.begin(), inst.end(), '(', ' ');
        replace(inst.begin(), inst.end(), ')', ' ');
        
        stringstream ts(inst);
        vector<string> tokens;
        string t;
        while (ts >> t) tokens.push_back(t);
        
        if (tokens.empty()) continue;
        
        string op = to_lower(tokens[0]);
        if (ISA.find(op) == ISA.end()) {
            cerr << "Error at PC=" << pc << ": Unknown instruction '" << op << "'" << endl;
            continue;
        }
        
        InstrFmt fmt = ISA[op];
        string bin_str = fmt.opcode;
        
        try {
            if (fmt.type == "R") {
                int rd = parse_reg(tokens[1]), rs1 = parse_reg(tokens[2]), rs2 = parse_reg(tokens[3]);
                bin_str += to_bin(rs1, 4) + to_bin(rs2, 4) + to_bin(rd, 4) + string(15, '0');
            } 
            else if (fmt.type == "R_1_reg") {
                int rd = parse_reg(tokens[1]), rs1 = parse_reg(tokens[2]);
                bin_str += to_bin(rs1, 4) + "0000" + to_bin(rd, 4) + string(15, '0');
            } 
            else if (fmt.type == "I") {
                int rd = parse_reg(tokens[1]), rs1 = parse_reg(tokens[2]);
                long long imm = parse_imm(tokens[3]);
                bin_str += to_bin(rs1, 4) + to_bin(rd, 4) + to_bin(imm, 19);
            } 
            else if (fmt.type == "I_MOV") {
                int rd = parse_reg(tokens[1]), rs1 = parse_reg(tokens[2]);
                bin_str += to_bin(rs1, 4) + to_bin(rd, 4) + to_bin(0, 19);
            } 
            else if (fmt.type == "I_LUI") {
                int rd = parse_reg(tokens[1]);
                long long imm = parse_imm(tokens[2]);
                bin_str += "0000" + to_bin(rd, 4) + to_bin(imm, 19);
            } 
            else if (fmt.type == "M") {
                int reg1 = parse_reg(tokens[1]);
                long long offset = parse_imm(tokens[2]);
                int reg2 = parse_reg(tokens[3]);
                bin_str += to_bin(reg2, 4) + to_bin(reg1, 4) + to_bin(offset, 19);
            } 
            else if (fmt.type == "B") {
                int rs1 = parse_reg(tokens[1]), rs2 = parse_reg(tokens[2]);
                string offset_str = to_lower(tokens[3]);
                long long offset = 0;
                if (labels.find(offset_str) != labels.end()) {
                    offset = labels[offset_str] - pc - 1; // PC-relative
                } else {
                    offset = parse_imm(offset_str);
                }
                bin_str += to_bin(rs1, 4) + to_bin(rs2, 4) + to_bin(offset, 19);
            } 
            else if (fmt.type == "J") {
                string offset_str = to_lower(tokens[1]);
                long long offset = 0;
                if (labels.find(offset_str) != labels.end()) {
                    offset = labels[offset_str]; // Absolute
                } else {
                    offset = parse_imm(offset_str);
                }
                bin_str += to_bin(offset, 27);
            } 
            else if (fmt.type == "JR") {
                int rs1 = parse_reg(tokens[1]);
                bin_str += to_bin(rs1, 4) + string(23, '0');
            } 
            else if (fmt.type == "SYS") {
                bin_str += string(27, '0');
            }
            
            binary_out.push_back(bin_str);
            
        } catch (const exception& e) {
            cerr << "Syntax error at PC=" << pc << ": " << instructions[pc] << endl;
        }
    }

    // --- Generate .coe file ---
    string output_filename = "memory.coe";
    ofstream outfile(output_filename);
    if (!outfile.is_open()) {
        cerr << "Failed to open " << output_filename << " for writing." << endl;
        return 1;
    }
    
    outfile << "memory_initialization_radix=2;\n";
    outfile << "memory_initialization_vector=\n";
    
    for (size_t i = 0; i < binary_out.size(); ++i) {
        outfile << binary_out[i] << (i == binary_out.size() - 1 ? ";" : ",") << "\n";
        cout << "PC=" << i << ": " << binary_out[i] << "\n";
    }
    
    outfile.close();
    cout << "\nSuccessfully generated " << output_filename << endl;

    return 0;
}