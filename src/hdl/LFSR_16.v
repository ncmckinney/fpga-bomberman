module LFSR_16
(
    input wire clk, rst, w_en,                          //active high write enable
    input wire [15:0] w_in,
    output wire [15:0] out
);

reg [15:0] data_reg, data_next;                         //register to hold LSFR data 

//infer registers for FSM
always @ (posedge clk, posedge rst) begin
    if(rst)
        data_reg <= 0;
    else
        data_reg <= data_next;
end

//LFSR FSM next state logic: Galois LFSR with taps at bits 16, 15, 13, and 4
always @*   begin
    if(w_en)                                            //load data when write enable active
        data_next = w_in;
    else    
        begin
        data_next = data_reg[15:1];                    //shift right one bit
        data_next[15] = data_reg[0];                   //feedback bit 1
        data_next[14] = data_reg[15] ^ data_reg[0];   //XOR input of each tap with feedback
        data_next[12] = data_reg[13] ^ data_reg[0]; 
        data_next[3] = data_reg[4] ^ data_reg[0];    
        end
end

assign out = data_reg;

endmodule
