`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/12/2018 04:38:46 PM
// Design Name: 
// Module Name: vga_sync
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//
// 31.77us 	Scanline time
//  3.77us 	Sync pulse lenght
//  1.89us 	Back porch
// 25.17us 	Display time
//  0.94us 	Front porch
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module vga_sync(
    input wire i_clk, reset,
    output wire o_hsync, o_vsync,
    output wire o_displayOn, o_pTick,
    output wire [9:0] o_x, o_y);
    
// 640 x 480 4:3 aspect ratio 
    parameter c_VdisplayLength  = 480;  // No. of display lines/rows v display last
    parameter c_VpulseWidth     = 2;    // No. of display lines/rows v sync goes low for retrace
    parameter c_VfrontPorch     = 10;
    parameter c_VbackPorch      = 33;    
    parameter c_VsyncEnd        = c_VfrontPorch + c_VpulseWidth;
    parameter c_VdisplayStart   = c_VsyncEnd + c_VbackPorch;
    
    parameter c_HdisplayLength  = 640;
    parameter c_HpulseWidth     = 96;
    parameter c_HfrontPorch     = 16;
    parameter c_HbackPorch      = 48;
    parameter c_HsyncEnd        = c_HfrontPorch + c_HpulseWidth;
    parameter c_HdisplayStart   = c_HsyncEnd + c_HbackPorch;
    
    parameter c_HlineEnd        = c_HdisplayLength + c_HpulseWidth + c_HfrontPorch + c_HbackPorch;  // No. of clock ticks for H sync duration
    parameter c_Vend            = c_VdisplayLength + c_VpulseWidth + c_VfrontPorch + c_VbackPorch;  // No. of display lines/rows v sync last 
      
    reg [9:0] r_Hcnt = 10'b0;
    reg [9:0] r_Vcnt = 10'b0;
    
    clk_div pixClk(
        .i_clk(i_clk),
        .o_clkSlow(o_pTick)
    );
        
    always @(posedge i_clk) begin
        if(reset)   begin
            r_Hcnt <= 10'b0;
            r_Vcnt <= 10'b0;
        end
        
        else    begin
            /*  Col and Row counters. Goes to next row after walking through each pixel in prev row */
            if (o_pTick)   begin
                if(r_Hcnt == c_HlineEnd - 1'b1) begin
                        r_Hcnt <= 10'b0;            //col set to zero
                        r_Vcnt <= r_Vcnt + 1'b1;    // increment row
                    end
                    
                else    r_Hcnt <= r_Hcnt + 1'b1;        //increment col until we hit edge of screen
                    
                if(r_Vcnt == c_Vend)    
                    r_Vcnt <= 9'b0;                //reset row after hitting bottom of screen
            end
        end
    end
        
    assign o_x = (r_Hcnt < c_HdisplayStart) ? 10'b0 : (r_Hcnt - c_HdisplayStart);             
    assign o_y = (r_Vcnt < c_VdisplayStart) ? 9'b0 : (r_Vcnt - c_VdisplayStart);
    
    assign o_hsync = ~((r_Hcnt >= c_HfrontPorch) & (r_Hcnt < c_HsyncEnd));                                                                 
    assign o_vsync = ~((r_Vcnt >= c_VfrontPorch) & (r_Vcnt < c_VsyncEnd));
    
    assign o_displayOn = ((r_Hcnt < c_HdisplayStart) | (r_Vcnt < c_VdisplayStart)) ? 1'b0 : 1'b1;
endmodule