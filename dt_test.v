module DT(clk, rst, done, sti_rd, sti_addr, sti_di, res_wr, res_rd, res_addr, res_do, res_di);
input clk;
input rst;
output done;
output sti_rd;
output [9:0] sti_addr;
input [15:0] sti_di;
output res_wr;
output res_rd;
output [13:0] res_addr;
output [7:0] res_do;
input [7:0] res_di;

parameter FORWARD_READ = 2'd0;
parameter FORWARD_CAL = 2'd1;
parameter BACKWARD_READ = 2'd2;
parameter BACKWARD_CAL = 2'd3;

reg done;
reg sti_rd;
reg [9:0] sti_addr;
reg res_wr;
reg res_rd;
reg [13:0] res_addr;
reg [7:0] res_do;

reg [1:0] change_state;
reg [3:0] change_bit;
reg [6:0] row_cnt, col_cnt; // 128
reg [2:0] col_cnt_8;

reg [1:0] state, next_state;
reg [7:0] pixal_F1, pixal_F2, pixal_F3, pixal_F4, pixal_FC;
reg [7:0] pixal_B1, pixal_B2, pixal_B3, pixal_B4, pixal_BC;
reg [7:0] min_forward, min_backward;
reg [7:0] min_forward_1, min_forward_2;
reg [7:0] min_backward_1, min_backward_2;

always @(posedge clk or negedge rst) begin
	if(!rst)
		state <= FORWARD_READ;
	else
		state <= next_state;
end 

always @(*) begin
	case(state) 
		FORWARD_READ: begin
			if(col_cnt == 7'd0)
				next_state = (change_state == 2'd2) ? FORWARD_CAL : FORWARD_READ;
			else 
				next_state = FORWARD_CAL;
		end
		FORWARD_CAL: begin
			if(col_cnt == 7'd125 && row_cnt == 7'd125)
				next_state = BACKWARD_READ;
			else
				next_state = FORWARD_READ;
		end
		BACKWARD_READ: begin
			if(col_cnt == 7'd127)
				next_state = (change_state == 2'd3) ? BACKWARD_CAL : BACKWARD_READ;
			else 
				next_state = (change_state == 2'd1) ? BACKWARD_CAL : BACKWARD_READ;
		end
		BACKWARD_CAL: begin
			next_state = BACKWARD_READ;			
		end
		///default : next_state = FORWARD_READ;
	endcase
end

always @(posedge clk or negedge rst) begin
	if(!rst) begin
		sti_rd <= 1'b1;
		sti_addr <= 10'd8;
		res_addr <= 14'd0;
		res_wr <= 1'b0;
		res_rd <= 1'b1;
		change_state <= 2'd0;
		row_cnt <= 7'd0;
		col_cnt_8 <= 3'd0;
		col_cnt <= 7'd0;
		change_bit <= 4'd0;
		done <= 1'b0;

		pixal_F1 <= 8'd0;
		pixal_F2 <= 8'd0;
		pixal_F3 <= 8'd0;
		pixal_F4 <= 8'd0;
		pixal_FC <= 8'd0;
		pixal_B1 <= 8'd0;
		pixal_B2 <= 8'd0;
		pixal_B3 <= 8'd0;
		pixal_B4 <= 8'd0;
		pixal_BC <= 8'd0;
	end
	else begin
		case(state)
			FORWARD_READ: begin
				if(col_cnt == 7'd0)
					change_state <= (change_state == 2'd2) ? 2'd0 : change_state + 2'd1;
				else 
					change_state <= 2'd0;

				if(col_cnt == 7'd0) begin
					case(change_state)
						2'd0: begin
							res_addr <= res_addr + 14'd1;
							pixal_F1 <= res_di;
						end
						2'd1: begin
							res_addr <= res_addr + 14'd1;
							pixal_F2 <= res_di;
						end
						2'd2: begin
							res_addr <= res_addr + 14'd127;
							pixal_F3 <= res_di;
							pixal_FC <= (col_cnt_8 == 3'd0) ? {7'd0, sti_di[14 - change_bit]} : {7'd0, sti_di[15 - change_bit]};
							res_wr <= 1'b1;
						end
					endcase
				end
				else begin
					res_addr <= res_addr + 14'd127;
					pixal_F1 <= pixal_F2;
					pixal_F2 <= pixal_F3;
					pixal_F3 <= res_di;
					pixal_FC <= (col_cnt_8 == 3'd0) ? {7'd0, sti_di[14 - change_bit]} : {7'd0, sti_di[15 - change_bit]};
					res_wr <= 1'b1;
				end
			end
			FORWARD_CAL: begin
				res_wr <= 1'b0;
				pixal_F4 <= (col_cnt == 7'd125) ? 8'd0 : res_do;

				row_cnt <= (col_cnt == 7'd125) ? row_cnt + 7'd1 : row_cnt;
				if(col_cnt_8 == 3'd0 || col_cnt_8 == 3'd7) begin
					change_bit <= (change_bit == 4'd14) ? 4'd0 : change_bit + 4'd1;
					col_cnt_8 <= (change_bit == 4'd14) ? col_cnt_8 + 3'd1 : col_cnt_8;
					sti_addr <= (change_bit == 4'd14) ? sti_addr + 10'd1 : sti_addr;
				end
				else begin
					change_bit <= (change_bit == 4'd15) ? 4'd0 : change_bit + 4'd1;
					col_cnt_8 <= (change_bit == 4'd15) ? col_cnt_8 + 3'd1 : col_cnt_8;
					sti_addr <= (change_bit == 4'd15) ? sti_addr + 10'd1 : sti_addr;
				end

				if(row_cnt == 7'd125 && col_cnt == 7'd125) begin
					res_addr <= 14'd16383;
					col_cnt <= 7'd127;
				end
				else begin
					res_addr <= res_addr - 14'd126;
					col_cnt <= (col_cnt == 7'd125) ? 7'd0 : col_cnt + 7'd1;
				end
			end
			BACKWARD_READ: begin
				if(col_cnt == 7'd127)
					change_state <= (change_state == 2'd3) ? 2'd0 : change_state + 2'd1;
				else
					change_state <= (change_state == 2'd1) ? 2'd0 : change_state + 2'd1;

				if(col_cnt == 7'd127) begin
					case(change_state)
						2'd0: begin
							res_addr <= res_addr - 14'd1;
							pixal_B4 <= res_di;
						end
						2'd1: begin
							res_addr <= res_addr - 14'd1;
							pixal_B3 <= res_di;
						end
						2'd2: begin
							res_addr <= res_addr - 14'd127;
							pixal_B2 <= res_di;
						end
						2'd3: begin
							res_addr <= res_addr;
							pixal_BC <= res_di;
							res_wr <= 1'b1;
						end
					endcase
				end
				else begin
					case(change_state)
						2'd0: begin
							pixal_B4 <= pixal_B3;
							pixal_B3 <= pixal_B2;
							pixal_B2 <= res_di;
							res_addr <= res_addr - 14'd127;
						end
						2'd1: begin
							res_addr <= res_addr;
							pixal_BC <= res_di;
							res_wr <= 1'b1;
						end
					endcase
				end
			end
			BACKWARD_CAL: begin
				res_wr <= 1'b0;
				res_addr <= res_addr + 14'd126;
				pixal_B1 <= (col_cnt == 7'd2) ? 8'd0 : res_do;
				col_cnt <= (col_cnt == 7'd2) ? 7'd127 : col_cnt - 7'd1;
				row_cnt <= (col_cnt == 7'd2) ? row_cnt - 7'd1 : row_cnt;
				if(row_cnt == 7'd1 && col_cnt == 7'd2)
					done <= 1'b1;
				else
					done <= 1'b0;
			end
		endcase
	end
end

always @(*) begin
	if(pixal_F1 > pixal_F2)
		min_forward_1 = pixal_F2;
	else
		min_forward_1 = pixal_F1;

	if(pixal_F3 > pixal_F4)
		min_forward_2 = pixal_F4;
	else 
		min_forward_2 = pixal_F3;

	if(min_forward_1 > min_forward_2)
		min_forward = min_forward_2;
	else 
		min_forward = min_forward_1;
end

always @(*) begin
	if(pixal_B1 > pixal_B2) 
		min_backward_1 = pixal_B2;
	else 
		min_backward_1 = pixal_B1;

	if(pixal_B3 > pixal_B4)
		min_backward_2 = pixal_B4;
	else 
		min_backward_2 = pixal_B3;

	if(min_backward_1 > min_backward_2) begin
		if((min_backward_2 + 8'd1) > pixal_BC)
			min_backward = pixal_BC;
		else 
			min_backward = min_backward_2 + 8'd1;
	end
	else begin
		if((min_backward_1 + 8'd1) > pixal_BC)
			min_backward = pixal_BC;
		else
			min_backward = min_backward_1 + 8'd1;
	end
end

always @(*) begin
	if(state == BACKWARD_CAL)
		res_do = (pixal_BC == 8'd0) ? 8'd0 : min_backward;
	else
		res_do = (pixal_FC == 8'd0) ? 8'd0 : min_forward + 8'd1;
end


endmodule

