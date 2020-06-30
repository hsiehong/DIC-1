
`timescale 1ns/10ps

module  SOBEL(clk,reset,busy,ready,iaddr,idata,cdata_rd,cdata_wr,caddr_rd,caddr_wr,cwr,crd,csel	);
input				clk;
input				reset;
output	reg 		busy;	
input				ready;	
output 	reg [16:0]		iaddr;
input  	[7:0]		idata;	
input	[7:0]		cdata_rd;
output	reg [7:0]		cdata_wr;
output 	[15:0]		caddr_rd;
output 	reg [15:0]	caddr_wr;
output	reg         cwr;
output              crd;
output 	reg [1:0]	csel;

parameter STATE_INIT   = 4'b0,
          STATE_REC    = 4'b1,
          STATE_SEND_X = 4'b10,
          STATE_SEND_Y = 4'b100,
          STATE_SEND_F = 4'b101,
          STATE_FIN    = 4'b11,
          STATE_SEC_REC = 4'b110,
          STATE_WAIT_1 = 4'b1000,
          STATE_WAIT = 4'b111,
          STATE_WAIT_2 = 4'b1001,
          STATE_WAIT_3 = 4'b1010,
          STATE_WAIT_4 = 4'b1011;
integer i;
reg [3:0] state;
reg [3:0] nxt_state;
reg [7:0] buffer[8:0];
reg [8:0] row;
reg [8:0] col;
reg [1:0] cnt;
reg act_cnt;
reg [16:0] base_addr;
reg nxt;
reg incr_addr;
reg incr_w_addr;
reg x;
reg data_ok;
reg [7:0]data_x;
reg [7:0]data_y;
reg signed[8:0] t1;
reg signed[9:0] t2;
reg signed[8:0] t3;
reg signed[9:0] t4;
reg signed[9:0] t5;
reg send_x;
reg send_y;
reg busyx;
wire [8:0]combine;
wire next_state;
wire [1:0] cmp_cnt;
wire nxt_col;
wire nxt_row;
wire first_row;
wire first_col;
wire last_row;
wire last_col;
wire [16:0] add_base_addr;
wire [16:0] add_i_addr1;
wire [16:0] add_i_addr2;
wire [7:0] mul1;
wire [7:0] mul2;
wire [7:0] mul3;
wire [7:0] mul4;
wire signed [8:0] add1;
wire signed [9:0] add2;
wire signed [8:0] add3;
wire signed [10:0] result;
wire [7:0] ans;

assign first_row = row == 9'b1;
assign first_col = col == 9'b1;
assign cmp_cnt   = (first_row) ? 2'b01 : 2'b10;
assign next_state = cnt == cmp_cnt;
assign nxt_col   = (next_state & first_col) | nxt;
assign nxt_row   = nxt_col & last_col;
assign last_row  = row == 9'd256; 
assign last_col  = col == 9'd257;
assign add_base_addr = (last_col & next_state) ? 17'd2:17'd1;
assign add_i_addr1 = (nxt_col & next_state) ? 17'd2 : nxt_col ? 17'd1 : 17'd258;
assign add_i_addr2 = (nxt_col & next_state) ? base_addr : nxt_col ? base_addr : iaddr;

assign mul1 = (x) ? buffer[2] : buffer[6];
assign add1 = {1'b0,buffer[8]} - {1'b0,mul1};
assign mul2 = (x) ? buffer[7] : buffer[5];
assign mul3 = (x) ? buffer[1] : buffer[3];
assign add2 = {1'b0,mul2,1'b0} - {1'b0,mul3,1'b0};
assign mul4 = (x) ? buffer[6] : buffer[2];
assign add3 = {1'b0,mul4} - {1'b0,buffer[0]};
assign result = t4 + t5;//(t1+t3) + t2;//(add1 + add3) + add2; 
assign ans = result[10] ? 8'b0 : |result[10:8] ? 8'hff : result[7:0];
assign combine = {1'b0,data_x} + {1'b0,data_y};

always@(posedge clk or posedge reset) begin
    if(reset) begin
       state <= STATE_INIT; 
    end
    else begin
        state <= nxt_state;
    end
end

always@(*)begin
    nxt_state = state;
    case(state)
        STATE_INIT  :nxt_state = (ready)?STATE_WAIT_1:STATE_INIT;
        STATE_WAIT_1 :nxt_state = STATE_WAIT_2;
        STATE_WAIT_2 :nxt_state = STATE_REC;
        STATE_REC   :nxt_state = (next_state & first_col) ? STATE_SEC_REC:(next_state)?STATE_WAIT:STATE_REC;
        STATE_SEC_REC :nxt_state = (next_state) ? STATE_WAIT :STATE_SEC_REC;
        STATE_WAIT  :nxt_state =STATE_WAIT_3;
        STATE_WAIT_3:nxt_state =STATE_SEND_X;
        STATE_SEND_X:nxt_state =STATE_SEND_Y;
        STATE_SEND_Y:nxt_state =STATE_SEND_F;
        STATE_SEND_F:nxt_state =(last_row & nxt_row)?STATE_FIN :STATE_REC;
    endcase
end

always@(*) begin
    act_cnt = 1'b0;
    nxt = 1'b0;
    busyx = 1'b1;
    incr_addr = 1'b0;
    incr_w_addr = 1'b0;
    csel = 2'b0;
    x = 1'b0;
    send_x = 1'b0;
    send_y = 1'b0;
    cwr = 1'b0;
    data_ok = 1'b0;
    cdata_wr = 8'b0;
    case(state)
        STATE_INIT:begin
            busyx = 1'b0;
        end
        STATE_REC:begin
            act_cnt = 1'b1;
            incr_addr = 1'b1;
            data_ok = 1'b1;
        end
        STATE_SEC_REC:begin
            act_cnt = 1'b1;
            incr_addr = 1'b1;
            data_ok = 1'b1;
        end
        STATE_WAIT:begin
            x = 1'b1;
        end
        STATE_SEND_X:begin
            send_x = 1'b1;
            csel = 2'b1;
            cwr = 1'b1;
            cdata_wr = ans;
        end
        STATE_SEND_Y:begin
            send_y = 1'b1;
            cwr = 1'b1;
            csel = 2'b10;
            cdata_wr = ans;
        end
        STATE_SEND_F:begin
            cwr = 1'b1;
            nxt = 1'b1;
            incr_addr = 1'b1;
            incr_w_addr = 1'b1;
            csel = 2'b11;
            cdata_wr = combine[8:1] + {7'b0,combine[0]};
        end
        STATE_FIN:begin
            busyx = 1'b0;
        end
    endcase
end

always@(posedge clk or posedge reset) begin
    if(reset) begin
        col <= 9'b1;
        row <= 9'b1;
        cnt <= 2'b0;
        base_addr <= 17'd258;
        caddr_wr <= 16'd0;
        iaddr <= 17'd259;
        t1 <= 9'b0;
        t2 <= 10'b0;
        t3 <= 9'b0;
        busy <= 1'b0;
        t4 <= 10'b0;
        t5 <= 10'b0;
    end
    else begin
        col <= (nxt_row) ? 9'b1 : (nxt_col) ? col + 9'b1 : col;
        row <= (nxt_row) ? row + 9'b1 : row;
        cnt <= (nxt_row | nxt_col ) ? 2'b0: act_cnt ? cnt + 2'b1 : cnt; 
        base_addr <=  (~next_state)?base_addr : (first_row & last_col)? 17'd258  : base_addr + add_base_addr;
        caddr_wr <= (incr_w_addr) ? caddr_wr + 16'd1 : caddr_wr;
        iaddr <= (~incr_addr)?iaddr: add_i_addr1 + add_i_addr2;
        data_x <= (send_x) ? ans:data_x;
        data_y <= (send_y) ? ans:data_y;
        t1 <= add1;
        t2 <= add2;
        t3 <= add3;
        busy <= busyx;
        t4 <= t1 + t3;
        t5 <= t2;
    end
end

always@(posedge clk or posedge reset) begin
    if(reset) begin
        for(i=0;i<9;i=i+1) 
            buffer[i] <= 8'b0;
    end
    else if(nxt_row) begin
        for(i=0;i<9;i=i+1) 
            buffer[i] <= 8'b0;
    end
    else if(data_ok) begin
        if(first_row)begin
            buffer[0] <= idata;
            buffer[1] <= buffer[0];
            buffer[3] <= buffer[1];
            buffer[4] <= buffer[3];
            buffer[6] <= buffer[4];
            buffer[7] <= buffer[6];  
        end
        else begin
            buffer[0] <= idata;
            for(i=0;i<8;i=i+1) 
                buffer[i+1] <= buffer[i];
        end
    end
end

endmodule
