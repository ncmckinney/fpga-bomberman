`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/12/2018 09:36:03 AM
// Design Name: 
// Module Name: clk_div
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module clk_div(
    input i_clk,
    output o_clkSlow
    );
    
    reg [15:0] r_cnt = 1'b0;        //counter large enough to hold four counts of strobe value
    reg r_clkStb;                   //clock strobe, transistions every 4 ticks of main clock
    parameter c_stbVal = 15'h4000;  //(2^16)/divider. In this case (2^16)/4
    
   //strobe signal r_clkStb is toggled every 4 ticks of the main clock
    always @(posedge i_clk)
        begin
            {r_clkStb,r_cnt} <= r_cnt + c_stbVal;
        end
        
    assign o_clkSlow = r_clkStb;
    
endmodule
