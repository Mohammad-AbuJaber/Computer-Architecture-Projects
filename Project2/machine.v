module machine();
reg CLK;
wire[23:0] PCnext, PCout, beforeInsReg, PCPlusTemp;
wire [23:0] insReg, RsReg, JBtrgReg, PCplus, BusBReg, ResultReg; 
wire[4:0] opCode;
wire[2:0] Rt_rtype,RA,RB,Rdesti,RW;
wire[23:0] BusA, BusB, BusW;
wire[16:0] immediate;
wire[23:0] immediateX, immediateShifted;
wire[1:0] cond;	// : cond should be assigned to the output of the insruction memory
wire isEqual, SF_ins;
wire[7:0] statusReg; // : the statusReg is an output of ALU
wire[2:0] ALUOp; //: this is the ALUOp in ALU
wire[1:0] RWsrc, PCsrc, memToReg;//  ALUsrc for the mux before ALU
	// : PCsrc is for the mux in fetch stage and memToReg is for the mux in WB stage
wire[23:0]ALUres;		
wire extendLen, regW, SF, memWr, memRd, PCWr, ALUsrc, RBsrc;
wire[4:0] state; // unneeded its just to echo the output of the CU
wire[23:0] addRes; 
wire[23:0] op1,op2; // the two operands in ALU 1 is the top and 2 is the buttom
assign SF_ins = insReg[16]; //** check again

assign opCode = insReg[21:17];
assign Rt_rtype = insReg[9:7];
assign RA = insReg[12:10];
assign Rdesti = insReg[15:13];		  
assign immediate = insReg[16:0];

PCregister PCMod(PCWr, PCnext, PCout);
assign PCPlusTemp = PCout + 1;
ins_memory insMemMod(PCout, beforeInsReg);
assign cond = beforeInsReg[23:22];
RegisternBit insRegMod(CLK, beforeInsReg, insReg); 
RegisternBit PCplusMod(CLK, PCPlusTemp, PCplus);

mux4X1 muxPCsrc (PCsrc, JBtrgReg, RsReg, PCplus, 24'h000000, PCnext);

mux4X1 #(.n(3)) muxbfRF(RWsrc, Rdesti, 3'b001, 3'b111, 3'b000, RW); //mux4X1(select,I0, I1, I2, I3, out)
mux2X1 #(.n(3)) muxRBsrc(RBsrc, Rt_rtype, Rdesti, RB);
registers_file rf(RA, RB, RW, regW, BusW, BusA, BusB);
RegisternBit op1Mod(CLK, BusA, op1);
RegisternBit BusBMod(CLK, BusB, BusBReg);

control_unit cu(CLK ,cond, opCode, SF_ins,isEqual, statusReg,state, PCWr, RBsrc, RWsrc, extendLen, regW, PCsrc, ALUsrc, SF, ALUOp, memWr, memRd, memToReg);

extender ext(immediate, extendLen, immediateX);

comparator comp1(BusA, BusB, isEqual);

adder adder1(PCout, immediateX, addRes);
RegisternBit JBtrgRegMod(CLK, addRes, JBtrgReg); 

shifter_left sl(immediate, immediateShifted); 

RegisternBit RsRegMod(CLK, BusA, RsReg);
	

mux2X1 ALUsrcMux (ALUsrc,BusBReg, immediateX, op2);
ALU alu(op1,op2,ALUOp,SF,ALUres,statusReg);

RegisternBit ResutlMod(CLK, ALUres, ResultReg); 
wire [23:0] memDataOut;
data_memory dataMemoryMod(ResultReg, memWr, memRd, BusBReg, memDataOut);
wire [23:0] memDataReg;
RegisternBit memDataMod(CLK, memDataOut, memDataReg);

mux4X1 muxWB (memToReg, ResultReg, memDataReg, PCplus, immediateShifted, BusW);

initial begin
	CLK = 0;
	
	repeat(100)
	#5ns CLK = !CLK;
	$finish;
end

endmodule 
module registers_file(RA, RB, RW, enableW, BusW, BusA, BusB);
	input[2:0] RA, RB, RW;
	input[23:0] BusW;
	input enableW;
	output [23:0] BusA, BusB;
	reg [23:0] file[0:7];
	
	initial begin
		file[0] = 0;
	end
	assign BusA = file[RA];	 
	assign BusB = file[RB];
	always@* begin
		if ((enableW==1) && (RW != 0)) begin
			file[RW] <= BusW;
		end
	end
endmodule

module rf_tb();
	reg[2:0] RA, RB, RW;
	reg[23:0] BusW;
	reg enableW;
	wire[23:0] BusA, BusB;
	registers_file rf(RA, RB, RW, enableW, BusW, BusA, BusB);
	initial begin
		RA = 1;
		RB = 0;
		RW = 1;
		enableW = 1;
		BusW = 24'h123456;
		repeat(6) begin
			#5ns RA <= RA + 1; 
			RB <= RB + 1;
			RW <= RW + 1;
			//enableW <= !enableW;
			BusW <= BusW + 1;
		end	
	end
endmodule


module ALU (operand1,operand2,ALU_OP,sfseg,res,statusReg);
    input [23:0] operand1;
    input [23:0] operand2;
    input [2:0] ALU_OP;
    input sfseg;
    output [23:0] res;
    output reg [7:0]statusReg;

    reg [23:0] result;
	initial begin
		statusReg = 8'b00000000;
	end
    always @(*) begin
        case (ALU_OP)
            3'b000: result = operand1 & operand2;//and + andi
            3'b001: result = operand1 < operand2 ? operand2 : operand1;//max
            3'b011: result = operand1 + operand2;//add + addi
            3'b100: result = operand1 - operand2;//sub + subi
            3'b101: result = operand1 >= operand2;//cmp 
            default: result = 0; 	
        endcase
		if (sfseg == 1) begin
			 statusReg[0] = (result==0);
			end
    end								   							 
    assign res = result;
endmodule

module ALU_tb;
    reg [23:0] operand1, operand2;
    reg [2:0] ALU_OP;
    reg sfseg;
    wire [23:0] res;
    wire [7:0]statusReg;
    ALU uut (
        .operand1(operand1),
        .operand2(operand2),
        .ALU_OP(ALU_OP),
        .sfseg(sfseg),
        .res(res),
        .statusReg(statusReg)
    );
    initial begin
		sfseg = 0;
        operand1 = 24'h012121;
        operand2 = 24'h987654;
        ALU_OP = 0;
		repeat(6)
			#5ns ALU_OP = ALU_OP + 1;
    end
endmodule


module control_unit(CLK ,cond, opCode, SF_ins,isEqual, statusReg,state, PCWr, RBsrc, RWsrc, extendLen, regW, PCsrc, ALUsrc, SF, ALUOp, memWr, memRd, memToReg);
	input CLK;
	input[1:0] cond;
	input[4:0] opCode;
	input isEqual, SF_ins;
	input[7:0] statusReg;
	output reg[2:0] ALUOp;
	output reg[1:0] RWsrc, PCsrc, memToReg;
	output reg extendLen, regW, SF, memWr, memRd, PCWr, ALUsrc, RBsrc;
	output reg[4:0] state;
	parameter AND=5'b00000,CAS=5'b00001, LWS=5'b00010, ADD=5'b00011, SUB=5'b00100, CMP=5'b00101, JR=5'b00110;
	parameter ANDI=5'b00111, ADDI=5'b01000, LW=5'b01001, SW=5'b01010, BEQ=5'b01011;
	parameter J=5'b01100, JAL=5'b01101 , LUI=5'b01110;
	// if aproblem accure we might need an IR enable  
	initial begin
		ALUOp = 0;
		ALUsrc = 0;
		RBsrc = 0;
		{RWsrc, memToReg}= 0;
		PCsrc = 2;
		{extendLen, regW, SF, memWr, memRd, PCWr} =0;
		state = 0;
	end
	always@(posedge CLK) begin
	#1ns
		case(state)
			0: begin
				regW = 0;
				memWr = 0;
				PCsrc =2;
				PCWr = 0;
				SF = 0;
				case(opCode)
					CMP: state = 1;
					AND,
					CAS,
					LWS,
					ADD,
					SUB: state = 2;
					ADDI,
					ANDI: state = 3;
					SW,
					LW: state = 4;
					JR: state = 5;
					BEQ: state = 6;
					JAL: state = 7;
					J: state = 8;
					LUI: state = 9;
					
				endcase
				if (cond == 1 && statusReg[0] == 0) begin
					PCWr = 1;
					#1ns PCWr = 0;
					state=0;
				end
				if (cond == 2 && statusReg[0] == 1) begin
					PCWr = 1;
					#1ns PCWr = 0;
					state=0;
				end
			end
			1: begin
				regW = 0;
				RBsrc = 0;
				state = 10;
			end
			2: begin
				RWsrc = 0;
				RBsrc = 0;
				state = 11;
			end
			3: begin
				RWsrc = 0;
				extendLen = 0;
				state = 12;
			end
			4: begin
				extendLen = 0;
				RBsrc = 1;
				state = 13;
			end
			5: begin
				PCsrc = 1;
				PCWr = 1; 
				#1ns PCWr = 0;
				state = 0;
			end
			6: begin
				extendLen = 0;
				PCWr = 1; 
				#1ns PCWr = 0;
				if (isEqual == 1) begin
					PCsrc = 0;
				end
				else begin
					PCsrc = 2;
				end
				state = 0;
			end
			7: begin
				extendLen = 1;
				PCsrc = 0;
				RWsrc = 2;
				state = 18;
			end
			8: begin
				extendLen = 1;
				PCsrc = 0;
				RWsrc = 2;
				PCWr = 1; 
				#1ns PCWr = 0;
				state = 0;
			end
			9: begin
				RWsrc=1;
				state = 19;
			end
			10: begin
				ALUsrc = 0;
				SF = 1;
				ALUOp = CMP[2:0];
				PCWr = 1;
				#1ns PCWr = 0;
				state = 0;
			end
			11:	begin 
				ALUsrc = 0;
				SF = SF_ins;
				ALUOp = opCode[2:0];
				state = 16;
			end
			12: begin
				ALUsrc = 1;
				SF = SF_ins;
				case(opCode)
					ANDI: ALUOp = AND[2:0];
					ADDI: ALUOp = ADD[2:0];
				endcase
				state = 16;
			end
			13: begin
				SF = 0;
				ALUsrc = 1;
				ALUOp = ADD[2:0];
				case(opCode)
					SW: state = 14;
					LW: state = 15;
				endcase
			end
			14: begin
				PCWr = 1;
				memWr = 1;
				#1ns memWr = 0;
				memRd = 0;
				PCWr = 0;
				state = 0;
			end
			15: begin
				memWr = 0;
				memRd = 1;
				state = 17;
			end
			16: begin
				memToReg = 0;
				regW = 1;
				PCWr = 1;
				#1ns PCWr = 0;
				regW = 0;
				state = 0;
			end
			17: begin
				memToReg = 1;
				regW = 1; 
				PCWr = 1;
				#1ns PCWr = 0;
				regW = 0;
				memRd = 0;
				state = 0;
			end
			18: begin
				memToReg = 2;
				regW = 1;
				PCWr = 1;
				#1ns PCWr = 0; 
				regW = 0;
				state = 0;
			end
			19: begin
				memToReg = 3;
				regW = 1;
				PCWr = 1;
				#1ns PCWr = 0;
				regW = 0;
				state = 0;
			end
		endcase
	end
	
	
endmodule


module PCregister (
    input PCWr,
    input [23:0] input_address,
    output reg [23:0] address,

);

initial begin
	 address = 0;
end

always @* begin
    if (PCWr) begin
        address <= input_address;
    end
end

endmodule

module PCregister_tb;
  reg PCWr;
  reg [23:0] input_address;

  wire [23:0] address;
  PCregister pcr (
    .PCWr(PCWr),
    .input_address(input_address),
    .address(address)
  );

  initial begin
    PCWr = 0;
    input_address = 0;	
    #5;
    PCWr = 1;
    input_address = 123;
    #5;
    PCWr = 0;
    input_address = 456;
    #5;
    PCWr = 1;
    input_address = 789;
    #5;
    PCWr = 0;
    #5;
  end
endmodule

module ins_memory(
	input[23:0] address,
	output reg [23:0] data_out,
	);
	reg [23:0] instructions[0:63]; //just used 64 addresses because 2^24 was an overkill for a simulation on our hardware
	assign data_out = instructions[address];
	
	parameter AND=5'b00000,CAS=5'b00001, LWS=5'b00010, ADD=5'b00011, SUB=5'b00100, CMP=5'b00101, JR=5'b00110;
	parameter ANDI=5'b00111, ADDI=5'b01000, LW=5'b01001, SW=5'b01010, BEQ=5'b01011;
	parameter J=5'b01100, JAL=5'b01101 , LUI=5'b01110;
	parameter R0=3'h0, R1=3'h1, R2=3'h2, R3=3'h3, R4=3'h4, R5=3'h5, R6=3'h6, R7=3'h7;
	initial begin
		instructions[0] = {2'b00, LUI, 17'h12345};					  // LUI 17'h12345
		instructions[1] = {2'b00, ADDI,1'b0, R1, R1,10'b0000101011};  // ADDI R1,R1, 2B
		instructions[2] = {2'b01, ADDI,1'b0, R1, R1,10'b0000101011};  // ADDIEQ R1, R1, 2B
		instructions[3] = {2'b00, ADDI,1'b0, R2, R0,10'b0000101011};  // ADDI R2, R0, 2B
		instructions[4] = {2'b00, SUB,1'b1, R3, R2, R2, 7'b0000000};  // SUBSF R3, R2, R2
		instructions[5] = {2'b00, CAS,1'b0, R4, R2, R1, 7'b0000000};  // CAS R4, R2, R1
		instructions[6] = {2'b00, CMP,1'b1, R3, R2, 10'b0000000000};  //  CMP R3, R2
		instructions[7] = {2'b00, AND,1'b0, R5, R2, R1, 7'b0000000};  // AND R5, R2, R1
		instructions[8] = {2'b00, ADDI,1'b0, R3, R0,10'b0000001100};  // ADDI R2, R0, 2B
		instructions[9] = {2'b00, JR,1'b0, R0, R3, R0, 7'b0000000};
		instructions[10] = {2'b00, SUB,1'b0, R3, R2, R2, 7'b0000000};  // SUBSF R3, R2, R2 dummy inst
		instructions[11] = {2'b00, SUB,1'b0, R3, R2, R2, 7'b0000000};  // SUBSF R3, R2, R2 dummy inst
		instructions[12] = {2'b00, SUB,1'b0, R3, R2, R2, 7'b0000000};  // SUBSF R3, R2, R2 dummy inst
		instructions[13] = {2'b00, ANDI,1'b0, R6, R2, 10'b0000011000}; // ANDI R6, R2, 10'h018
		instructions[14] = {2'b00, SW,1'b0, R6, R2, 10'b0000000000}; 
		instructions[15] = {2'b00, LW,1'b0, R5, R2, 10'b0000000000};
		//instructions[6] = {2'b00, LWS,1'b1, R3, R2, 10'b0000000000};
		//instructions[4] = {2'b00, BEQ,1'b1, R3, R0, 10'b0000000};
		
	end
endmodule

module ins_memory_tb();
	reg[23:0] address;
	wire[23:0] data_out;
	
	ins_memory imtb(address, data_out);
	
	initial begin
		address = 0;
		
		repeat(2)
		#5ns address = address + 1;
		
		$finish;
	end
endmodule

module data_memory (
    input [23:0] address,
    input memWr,
    input memRd,
    input [23:0] data_in,
    output reg [23:0] data_out
);

reg [23:0] memory [0:511];

always @* begin
    if (memWr) begin
        memory[address] <= data_in;
    end
end
assign data_out = memRd ? memory[address] : 24'h000000; // if memRd = 1	==> data_out = mem[address] else ==> 0

endmodule


module data_memory_tb;

reg [23:0] address;
reg memWr, memRd;
reg [23:0] data_in;
wire [23:0] data_out;

data_memory mem (
    .address(address),
    .memWr(memWr),
    .memRd(memRd),
    .data_in(data_in),
    .data_out(data_out)
);

initial begin
    // write data to address 0 and 1
    address = 0;
    memWr = 1;
    data_in = 24'h012345;
    #10;
    address = 1;
    data_in = 24'h678901;
    #10;

    // read data from address 0 and 1
    address = 0;
    memWr = 0;
    memRd = 1;
    #10;
    address = 1;
    #10;
end

endmodule

module control_unit_tb();
	reg CLK;
	reg[1:0] cond;
	reg[4:0] opCode;
	reg isEqual, SF_ins;
	reg[7:0] statusReg;
	wire [2:0] ALUOp;
	wire [1:0] RWsrc, PCsrc, memToReg;
	wire extendLen, regW, SF, memWr, memRd, PCWr, ALUsrc, RBsrc;
	wire[4:0] state;
	reg[4:0] opCodeReg[14:0];
	parameter AND=5'b00000,CAS=5'b00001, LWS=5'b00010, ADD=5'b00011, SUB=5'b00100, CMP=5'b00101, JR=5'b00110;
	parameter ANDI=5'b00111, ADDI=5'b01000, LW=5'b01001, SW=5'b01010, BEQ=5'b01011;
	parameter J=5'b01100, JAL=5'b01101 , LUI=5'b01110;
	control_unit cu(CLK ,cond, opCode, SF_ins,isEqual, statusReg,state, PCWr, RBsrc, RWsrc, extendLen, regW, PCsrc, ALUsrc, SF, ALUOp, memWr, memRd, memToReg);
	initial begin
		CLK = 0;
		cond = 0;
		SF_ins = 0;
		opCodeReg[0] = AND;
		opCodeReg[1] = CAS;
		opCodeReg[2] = LWS;
		opCodeReg[3] = ADD;
		opCodeReg[4] = SUB;
		opCodeReg[5] = CMP;
		opCodeReg[6] = JR;
		opCodeReg[7] = ANDI;
		opCodeReg[8] = ADDI;
		opCodeReg[9] = LW;
		opCodeReg[10] = SW;
		opCodeReg[11] = BEQ;
		opCodeReg[12] = J;
		opCodeReg[13] = JAL;
		opCodeReg[14] = LUI;
		opCode = opCodeReg[0];
		isEqual = 1;
		statusReg = 8'h01;
		for (int i=0;i<=14; i++) begin
			opCode = opCodeReg[i];
			do  begin
				#5ns CLK = !CLK;
				#5ns CLK = !CLK;
			end
			while (state != 0);
		end
	end
endmodule
// small helper modules in decode stage
//-------------------------------------------------------
module extender(imm, extendLen, out);
	input extendLen;
	input[16:0] imm;
	output reg[23:0] out;
	
	always@* begin
		if (extendLen == 0) begin
			out[9:0] = imm[9:0];
			for (int i=10;i<24;i++) begin
				out[i] = imm[9];
			end
		end
		else begin
			out[16:0] = imm[16:0];
			for (int i=17;i<24;i++) begin
				out[i] = imm[16];
			end
		end
	end
	
endmodule

module extender_tb();
	reg extendLen;
	reg[16:0] imm;
	wire[23:0] out;
	extender e(imm, extendLen, out);
	
	initial begin
		#5ns extendLen = 0;
		imm = 17'h01134;
		#5ns extendLen = 0;
		imm = 17'h01334;
		#5ns extendLen = 1;
		imm = 17'h01134;
		#5ns extendLen = 1;
		imm = 17'h11334;
		
	end
	
endmodule

module adder(A, B, out);
	input[23:0] A, B;
	output[23:0] out;
	
	assign out = A + B;	
endmodule

module adder_tb();
	reg[23:0] A, B;
	wire[23:0] out;
	adder adder1(A, B, out);
	
	initial begin
		#5ns A = 24'h123456;
		B = 24'h123343;
		#5ns A = 24'h123456;
		B = 24'hFF1334;
		
	end
endmodule

module comparator(A, B, eq);
	input[23:0] A, B;
	output eq;
	
	assign eq = (A==B)? 1:0;
	
endmodule

module comparator_tb();
	reg[23:0] A, B;
	wire eq;
	comparator c1(A, B, eq);
	initial begin
		#5ns A = 24'h444444;
		B = 24'h444444;
		#5ns A = 24'h444444;
		B = 24'h444344;
		#5ns A = 24'h444444;
		B = 24'h444444;
		#5ns A = 24'h444444;
		B = 24'h444344;
	end
	
endmodule

module DFlipFlop(CLK,D,Q,Qb);
	input D,CLK;
	output reg Q,Qb;
	assign Qb=~Q;
	always @(posedge CLK)
		begin
		Q<=D;
		end
	
endmodule

module RegisternBit(CLK, D, Q);
	parameter n=24;
	input [(n-1):0] D;
	input CLK;
	output [(n-1):0] Q;
	wire [(n-1):0] te;
	genvar i;
	
	generate
	for(i=0;i<n;i=i+1)
		begin:register
			DFlipFlop dff(CLK,D[i],Q[i],te[i]);
		end
	endgenerate
	
endmodule

module shifter_left(in, out);
	parameter size = 24;
	parameter amount = 7;
	input[16:0] in;
	output[23:0] out;
	
	assign out[(amount-1):0] = 0;
	assign out[(size-1):amount] = in;
endmodule

module shifter_left_tb();
	reg[16:0] in;
	wire[23:0] out;
	shifter_left sl(in, out);
	
	initial begin
		#5ns in  = 17'h12345;
	end
endmodule

module mux2X1(select,I0, I1, out);
	parameter n = 24;
	input select;
	input[(n-1):0] I0, I1;
	output[(n-1):0] out;
	
	assign out = (select) ? I1: I0;
	
	
endmodule

module mux2X1_tb();
	reg select;
	reg[2:0] I0, I1;
	wire[2:0] out;
	mux2X1 #(.n(3)) m21(select,I0, I1, out);
		
	initial begin
		I0 <= 24'h123456;
		I1 <= 24'h789ABC;
		select <= 0;
		#5ns select <= 1;
	end
endmodule

module mux4X1(select,I0, I1, I2, I3, out);
	parameter n = 24;
	input[1:0] select;
	input[(n-1):0] I0, I1, I2, I3;
	output[(n-1):0] out;
	
	assign out = (select[1]) ? ((select[0])? I3: I2):((select[0])? I1: I0);
	
	
endmodule

module mux4X1_tb();
	reg[1:0] select;
	reg[23:0] I0, I1, I2, I3;
	wire[23:0] out;
	mux4X1 m41(select,I0, I1,I2, I3, out);
		
	initial begin
		I0 <= 24'h111222;
		I1 <= 24'h333444;
		I2 <= 24'h555666;
		I3 <= 24'h777888;
		select <= 0;
		repeat(3)
		#5ns select <= select + 1;
	end
endmodule
//-------------------------------------------------
