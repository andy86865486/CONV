
`timescale 1ns/10ps

module  CONV(
	input						clk,
	input						reset,
	output	reg					busy,	
	input						ready,	
			
	output	reg 		[11:0]	iaddr,
	input		signed	[19:0]	idata,	
	
	output	reg 				cwr,
	output	reg 		[11:0]	caddr_wr,
	output	reg	signed	[19:0]	cdata_wr,
	
	output	reg 				crd,
	output	reg 		[11:0]	caddr_rd,
	input		signed 	[19:0]	cdata_rd,
	
	output	reg 		[2:0]	csel
	);

//------------------------------------------------------
reg [3:0] cur_state, next_state;
// 座標計數器 (0 ~ 63)
reg [5:0] x, y, target_col; 
// 讀取子計數器 (0, 1, 2) - 用於讀取 Top, Mid, Bot
reg [2:0] r_cnt; 
//
reg signed[19:0]w3[0:2][0:2];
//
//reg signed[19:0]w2[0:1][0:1];
reg signed[19:0]current_max;
//kernel and bias
//wire signed[19:0]kernel[0:2][0:2];
//wire signed[19:0]bias;
//maxpooling result
//wire signed[19:0]max_r0;
//wire signed[19:0]max_r1;
//wire signed[19:0]max_r;
//relu result
wire signed[19:0]relu_r;
//convolution result
wire signed[39:0]conv_r0;
wire signed[39:0]conv_r1;
wire signed[39:0]conv_r2;
wire signed[39:0]conv_r3;
wire signed[39:0]conv_r4;
wire signed[39:0]conv_r5;
wire signed[39:0]conv_r6;
wire signed[39:0]conv_r7;
wire signed[39:0]conv_r8;
wire signed[39:0]conv_sum;
wire signed[19:0]conv_sum_final;

//parameters for FSM
localparam S_IDLE = 4'd0;
localparam S_FILL_L = 4'd1;
localparam S_FILL_C = 4'd2;
localparam S_FILL_R = 4'd3;
localparam S_L0 = 4'd4;
localparam S_FILL_4 = 4'd5;
localparam S_L1 = 4'd6;
localparam S_DONE = 4'd7;

//kernel and bias
localparam signed [19:0] k00 = 20'sh0A89E, k10 = 20'sh092D5, k20 = 20'sh06D43;
localparam signed [19:0] k01 = 20'sh01004, k11 = 20'shF8F71, k21 = 20'shF6E54;
localparam signed [19:0] k02 = 20'shFA6D7, k12 = 20'shFC834, k22 = 20'shFAC19;
localparam signed [19:0] bias = 20'sh01310;

//-----------------FSM_Update_State---------------------
always @(posedge clk or posedge reset) begin
	if (reset) cur_state <= S_IDLE;
	else       cur_state <= next_state;
end

always @(*) begin
	case(cur_state)
	
	S_IDLE : begin
	if (ready) next_state = S_FILL_L;
	else next_state = S_IDLE;
	end
	
	S_FILL_L : begin
	if (r_cnt == 3'd3) next_state = S_FILL_C;
	else next_state = S_FILL_L;
	end
	
	S_FILL_C : begin
	if (r_cnt == 3'd3) next_state = S_FILL_R;
	else next_state = S_FILL_C;
	end
	
	S_FILL_R : begin
	if (r_cnt == 3'd3) next_state = S_L0;
	else next_state = S_FILL_R;
	end
	
	S_L0 : begin
	if (x == 6'd63 && y == 6'd63) next_state = S_FILL_4;
	else if (x == 6'd63) next_state = S_FILL_L;
	else next_state = S_FILL_R;
	end
	
	S_FILL_4 : begin
	if (r_cnt == 3'd5) next_state = S_L1;
	else next_state = S_FILL_4;
	end
	
	S_L1 : begin
	if (x == 6'd31 && y == 6'd31) next_state = S_DONE;
	else next_state = S_FILL_4;
	end
	
	S_DONE: begin
	next_state = S_IDLE;
	end
	
	default : next_state = S_IDLE;
	endcase
end

//-------------------FILL_OFFSET---------------------------
always @(*) begin
	case(cur_state)
	S_FILL_L : target_col = x - 1'b1;
	S_FILL_C : target_col = x;
	S_FILL_R : target_col = x + 1'b1;
	default: target_col = x;
	endcase
end

//-----------------DATA_PATH---------------------------

always @(posedge clk or posedge reset) begin
	if (reset) begin
	r_cnt <= 3'b0;
	busy <= 1'b0;
	end

	else begin
	case(cur_state)
	
	S_IDLE : begin
	cwr <= 1'b0;
	crd <= 1'b0;
	x <= 6'd0;
	y <= 6'd0;
	r_cnt <= 3'd0;
	busy <= 1'b0;
	
	end
	
	S_FILL_L : begin
	busy <= 1'b1;
	cwr <= 1'b0;
	case(r_cnt)
	3'd0 : iaddr <= {(y - 1'b1), target_col};
	3'd1 : begin
		iaddr <= {(y  ), target_col};
		if (x == 6'd0 || y == 6'd0) w3[0][0] <= 20'sd0;
		else w3[0][0] <= idata ;
		end
	3'd2 : begin
		iaddr <= {(y + 1'b1), target_col};
		if (x == 6'd0) w3[0][1] <= 20'sd0;
		else w3[0][1] <= idata ;
		end
	3'd3 : begin
		if (x == 6'd0 || y == 6'd63) w3[0][2] <= 20'sd0;
		else w3[0][2] <= idata ;
		caddr_wr <= {y, x};
		csel <= 3'b001;
	end
	endcase
	if (r_cnt < 3'd3) r_cnt <= r_cnt + 1'b1;
	else r_cnt <= 3'd0;
	end
	
	S_FILL_C : begin
	cwr <= 1'b0;
	case(r_cnt)
	3'd0 : iaddr <= {(y - 1'b1), target_col};
	3'd1 : begin
		iaddr <= {(y  ),target_col};
		if (y == 6'd0) w3[1][0] <= 20'sd0;
		else w3[1][0] <= idata ;
		end
	3'd2 : begin
		iaddr <= {(y + 1'b1), target_col};
		w3[1][1] <= idata ;
		end
	3'd3 : if (y == 6'd63) w3[1][2] <= 20'sd0;
		else w3[1][2] <= idata ;
	endcase
	if (r_cnt < 3'd3) r_cnt <= r_cnt + 1'b1;
	else r_cnt <= 3'd0;
	end
	
	S_FILL_R : begin
	cwr <= 1'b0;
	case(r_cnt)
	3'd0 : iaddr <= {(y - 1'b1), target_col};
	3'd1 : begin
		iaddr <= {(y  ), target_col};
		if (x == 6'd63 || y == 6'd0) w3[2][0] <= 20'sd0;
		else w3[2][0] <= idata ;
		end
	3'd2 : begin
		iaddr <= {(y + 1'b1), target_col};
		if (x == 6'd63) w3[2][1] <= 20'sd0;
		else w3[2][1] <= idata ;
		end
	3'd3 : begin
		if (x == 6'd63 || y == 6'd63) w3[2][2] <= 20'sd0;
		else w3[2][2] <= idata ;
		caddr_wr <= {y, x};
		csel <= 3'b001;
		end
	endcase
	if (r_cnt < 3'd3) r_cnt <= r_cnt + 1'b1;
	else r_cnt <= 3'd0;
	end
	
	S_L0 : begin
	cwr <= 1'b1;
	cdata_wr <= relu_r;

	if ((y == 6'd63) && (x == 6'd63)) begin
		x <= 6'd0;
		y <= 6'd0;
		end
	else if ((x== 6'd63)) begin
		x <= 6'd0;
		y <= y + 1'b1;
		end
	else begin
		x <= x + 1'b1;
		{w3[0][0], w3[1][0]} <= {w3[1][0], w3[2][0]};
		{w3[0][1], w3[1][1]} <= {w3[1][1], w3[2][1]};
		{w3[0][2], w3[1][2]} <= {w3[1][2], w3[2][2]};
		end
	end
	
	S_FILL_4 : begin
	case(r_cnt)
	3'd0 : begin
		cwr <= 1'b0;
		crd <= 1'b1;
		csel <= 3'b001;
		end
	3'd1 : caddr_rd <= { y[4:0], 1'b0, x[4:0], 1'b0 };//{(y*2), (x*2)};0,2,4
	3'd2 : begin
		caddr_rd <= { y[4:0], 1'b0, x[4:0], 1'b1 }; //{(y*2), (x*2+1)};1,3,5
		current_max <= cdata_rd;
		end
	3'd3 : begin
		caddr_rd <= { y[4:0], 1'b1, x[4:0], 1'b0 }; //{(y*2+1), (x*2)};64,66,68
		if (cdata_rd > current_max) begin
			current_max <= cdata_rd;
			end
		end
	3'd4 : begin
		caddr_rd <= { y[4:0], 1'b1, x[4:0], 1'b1 }; //{(y*2+1), (x*2+1)};65,67,69
		if (cdata_rd > current_max) begin
			current_max <= cdata_rd;
			end
		end
	3'd5 : begin
		if (cdata_rd > current_max) begin
			current_max <= cdata_rd;
			end
		end
	endcase
	if (r_cnt < 3'd5) r_cnt <= r_cnt + 1'b1;
	else r_cnt <= 3'd0;
	end
	
	// S_L1 : write to memory, set address and data to write, select memory layer
	S_L1 : begin
	cwr <= 1'b1;
	crd <= 1'b0;
	caddr_wr <= {2'b0, y[4:0], x[4:0]};
	cdata_wr <= current_max;
	csel <= 3'b011;
	if ((y == 6'd31) && (x == 6'd31)) begin
		x <= 6'd0;
		y <= 6'd0;
		end
	else if ((x == 6'd31))begin
		x <= 6'd0;
		y <= y + 1'b1;
		end
	else begin
		x <= x + 1'b1;
		end
	end
	
	S_DONE: begin
	busy <= 1'b0;
	end
	
	//default : cwr <= 1'b0;
	endcase
	end
end
//-------------------L0-----------------------


//assign kernel[0][0] = 20'sh0A89E;
//assign kernel[1][0] = 20'sh092D5;
//assign kernel[2][0] = 20'sh06D43;
//assign kernel[0][1] = 20'sh01004;
//assign kernel[1][1] = 20'shF8F71;
//assign kernel[2][1] = 20'shF6E54;
//assign kernel[0][2] = 20'shFA6D7;
//assign kernel[1][2] = 20'shFC834;
//assign kernel[2][2] = 20'shFAC19;
//assign bias = 20'sh01310;

//convolution+bias
assign conv_r0 = (w3[0][0] * k00);
assign conv_r1 = (w3[1][0] * k10);
assign conv_r2 = (w3[2][0] * k20);
assign conv_r3 = (w3[0][1] * k01);
assign conv_r4 = (w3[1][1] * k11);
assign conv_r5 = (w3[2][1] * k21);
assign conv_r6 = (w3[0][2] * k02);
assign conv_r7 = (w3[1][2] * k12);
assign conv_r8 = (w3[2][2] * k22);
assign conv_sum = conv_r0 + conv_r1 + conv_r2 + conv_r3 + conv_r4 + conv_r5 + conv_r6 + conv_r7 + conv_r8 + $signed({bias, 16'b0}); //拼接運算 {} 的結果預設是無號數 (Unsigned)。根據黃金法則：「運算式中只要有一個無號數，整個運算都會變成無號數」。
assign conv_sum_final = conv_sum[35:16] + conv_sum[15];

//relu
assign relu_r = (conv_sum_final > 20'sd0) ? conv_sum_final : 20'sd0;

//--------------------L1----------------------

//maxpooling(compartor)
//assign max_r0 = (w2[0][0] >= w2[1][0]) ? w2[0][0] : w2[1][0];
//assign max_r1 = (w2[0][1] >= w2[1][1]) ? w2[0][1] : w2[1][1];
//assign max_r = (max_r0 >= max_r1) ? max_r0 : max_r1;
//assign max_r = (w2[0][0]>=w2[0][1])?(w2[0][0]>=w2[1][0])?(w2[0][0]>=w2[1][1])?w2[0][0]:w2[1][1]:(w2[1][0]>=w2[1][1])?w2[1][0]:w2[1][1]:(w2[0][1]>=w2[1][0])?(w2[0][1]>=w2[1][1])?w2[0][1]:w2[1][1]:(w2[1][0]>=w2[1][1])?w2[1][0]:w2[1][1]; //太亂

endmodule
