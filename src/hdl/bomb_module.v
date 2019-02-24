module bomb_module
(
   input wire clk, reset,
   input wire [9:0] x_a, y_a,              // current pixel location on screen in arena coordinate frame
   input wire [1:0] cd,                    // bomberman current direction
   input wire [9:0] x_b, y_b,              // bomberman coordinates
   input wire A,                           // bomb button input
   input wire gameover,                    // signal from game_lives module, asserted when gameover
   output wire [11:0] bomb_rgb, exp_rgb,   // rgb output for bomb and explosion tiles
   output wire bomb_on, exp_on,            // signals asserted when vga x/y pixels are within bomb or explosion tiles on screen
   output wire [9:0] block_w_addr,         // adress into block map RAM of where explosion is to clear block
   output wire block_we,                   // write enable signal into block map RAM
   output reg post_exp_active              // signal asserted when bomb_exp_state_reg == post_exp, bomb is active on screen
);

localparam BM_HB_OFFSET_9 = 9;             // offset from top of sprite down to top of 16x16 hit box  
localparam BM_HB_HALF     = 8;             // half length of bomberman hitbox

localparam X_WALL_L = 48;                  // end of left wall x coordinate
localparam X_WALL_R = 576;                 // begin of right wall x coordinate
localparam Y_WALL_U = 32;                  // bottom of top wall y coordinate
localparam Y_WALL_D = 448;                 // top of bottom wall y coordinate

localparam BOMB_COUNTER_MAX = 220000000;   // max values for counters used for bomb and explosion timing
localparam EXP_COUNTER_MAX  = 120000000;

// symbolic state declarations
localparam [3:0] no_bomb  = 3'b000,  // no bomb on screen
                 bomb     = 3'b001,  // bomb on screen for 1.5 s
                 exp_1    = 3'b010,  // take care of explostion tile 1
                 exp_2    = 3'b011,  // 2
                 exp_3    = 3'b100,  // 3
                 exp_4    = 3'b101,  // 4
                 post_exp = 3'b110;  // wait for .75 s to finish
                 
// 16 bit tile offset from bomberman
localparam X_BOMB_OFFSET = 3;               
localparam Y_BOMB_OFFSET = 1;               
/*  
The labeling for explosion tiles "e_x" relative to the bomb "b" is shown below
           e_3
       e_1  b  e_2
           e_4
*/         
          
reg [3:0] bomb_exp_state_reg, bomb_exp_state_next;   // FSM register and next-state logic
reg [5:0] bomb_x_reg, bomb_y_reg;                    // bomb ABM coordinate location register 
reg [5:0] bomb_x_next, bomb_y_next;                  // and next-state logic
reg bomb_active_reg, bomb_active_next;               // register asserted when bomb is on screen
reg exp_active_reg, exp_active_next;                 // register asserted when explosion is active on screen.
reg [9:0] exp_block_addr_reg, exp_block_addr_next;   // address to write a 0 to block map to clear a block hit by explosion.
reg block_we_reg, block_we_next;                     // register to enable block map RAM write enable
reg  [27:0] bomb_counter_reg;                        // counter register to track how long a bomb exists before exploding
wire [27:0] bomb_counter_next;
reg  [26:0] exp_counter_reg;                         // counter register to track how long an explosion lasts
wire [26:0] exp_counter_next;

// x/y bomb coordinates translated to arena coordinates
wire [9:0] x_bomb_a, y_bomb_a;
assign x_bomb_a = x_b + BM_HB_HALF - X_WALL_L; 
assign y_bomb_a = y_b + BM_HB_HALF + BM_HB_OFFSET_9 - Y_WALL_U; 

// infer bomb counter register
always @(posedge clk, posedge reset)
   if(reset)
      bomb_counter_reg <= 0;
   else
      bomb_counter_reg <= bomb_counter_next;

// bomb counter next-state logic: if bomb is active and counter < max, count up.
assign bomb_counter_next = (bomb_active_reg & bomb_counter_reg < BOMB_COUNTER_MAX) ? bomb_counter_reg + 1 : 0;

// infer explosion counter register
always @(posedge clk, posedge reset)
   if(reset)
      exp_counter_reg <= 0;
   else
      exp_counter_reg <= exp_counter_next;
      
// explosion counter next-state logic: is explosion active and counter < max, count up
assign exp_counter_next = (exp_active_reg & exp_counter_reg < EXP_COUNTER_MAX) ? exp_counter_reg + 1 : 0;

// infer registers used in FSM
always @(posedge clk, posedge reset)
   if(reset)
      begin
      bomb_exp_state_reg <= no_bomb;
      bomb_active_reg    <= 0;
      exp_active_reg     <= 0;
      bomb_x_reg         <= 0;
      bomb_y_reg         <= 0;
      exp_block_addr_reg <= 0;
      block_we_reg       <= 0;
      end
   else
      begin
      bomb_exp_state_reg <= bomb_exp_state_next;
      bomb_active_reg    <= bomb_active_next;
      exp_active_reg     <= exp_active_next;
      bomb_x_reg         <= bomb_x_next;
      bomb_y_reg         <= bomb_y_next;
      exp_block_addr_reg <= exp_block_addr_next;
      block_we_reg       <= block_we_next;
      end
       
       
// bomb and explosion FSM: idle until bomb button pressed
// controls bomb and explosion placement and duration, address of block removal, and triggers post explosion affects on enemy and player
always @*
   begin 
   // defaults
   bomb_exp_state_next = bomb_exp_state_reg;
   bomb_active_next    = bomb_active_reg;
   exp_active_next     = exp_active_reg;
   bomb_x_next         = bomb_x_reg;
   bomb_y_next         = bomb_y_reg;
   exp_block_addr_next = exp_block_addr_reg;
   block_we_next       = block_we_reg;
   post_exp_active     = 0;
	
   case(bomb_exp_state_reg)
    no_bomb:    if (A && !gameover) 
                    begin
                    bomb_active_next = 1;                       //allows bomb counter to run: displays till counter max
                    bomb_x_next = x_b[9:4] - X_BOMB_OFFSET ;    //current tile bomberman occupies
                    bomb_y_next = y_b[9:4] - Y_BOMB_OFFSET ;    //current tile bomberman occupies
                    bomb_exp_state_next = bomb;                 
                    end
    bomb:       if (bomb_counter_reg == BOMB_COUNTER_MAX)
                    begin
                    bomb_active_next = 0;                       //bomb disappers after counter period
                    exp_active_next = 1;                        //allows explosion counter to run: displays till counter max 
                    block_we_next = 1;                          //allow write to block map RAM
                    bomb_exp_state_next = exp_1;
                    end
    exp_1:      if (bomb_x_reg != 0)
                    begin
                    exp_block_addr_next = ((bomb_x_reg - 1) + (bomb_y_reg)*33); //location of left explosion: used to remove blocks
                    bomb_exp_state_next = exp_2;
                    end
                else    bomb_exp_state_next = exp_2;
    exp_2:      if (bomb_x_reg != (X_WALL_R - X_WALL_L))
                    begin
                    exp_block_addr_next = ((bomb_x_reg + 1) + (bomb_y_reg)*33); //location of right explosion: used to remove blocks
                    bomb_exp_state_next = exp_3;
                    end
                else    bomb_exp_state_next = exp_3;
    exp_3:      if (bomb_y_reg != 0)
                    begin
                    exp_block_addr_next = ((bomb_x_reg) + (bomb_y_reg - 1)*33); //location of top explosion: used to remove blocks
                    bomb_exp_state_next = exp_4;
                    end
                else    bomb_exp_state_next = exp_4;
    exp_4:      if (bomb_y_reg != (Y_WALL_D - Y_WALL_U))
                    begin
                    exp_block_addr_next = ((bomb_x_reg) + (bomb_y_reg + 1)*33); //location of bottom explosion: used to remove blocks
                    bomb_exp_state_next = post_exp;
                    end
                else    bomb_exp_state_next = post_exp;
    post_exp:   if (exp_counter_reg == EXP_COUNTER_MAX)
                    begin
                    post_exp_active = 1;                //flag to trigger status of enemies affected by blast
                    exp_active_next = 0;                //end explosion
                    block_we_next = 0;                  //end write access to block map RAM
                    bomb_exp_state_next = no_bomb;
                    end
   endcase
	
   
end        // END FSM next-state logic 


// bomb_on asserted when bomb x/y arena block map coordinates equal that of x/y ABM coordinates and bomb is active
assign bomb_on = (x_a[9:4] == bomb_x_reg & y_a[9:4] == bomb_y_reg & bomb_active_reg);

// explosion_on asserted when appropriate tile location with respect to bomb ABM coordinates matches
// x/y ABM coordinates
assign exp_on = (exp_active_reg &(
                (                   x_a[9:4] == bomb_x_reg   & y_a[9:4] == bomb_y_reg  ) |  // center
                (bomb_x_reg != 0  & x_a[9:4] == bomb_x_reg-1 & y_a[9:4] == bomb_y_reg  ) |  // exp_1
                (bomb_x_reg != 32 & x_a[9:4] == bomb_x_reg+1 & y_a[9:4] == bomb_y_reg  ) |  // exp_2
                (bomb_y_reg != 0  & x_a[9:4] == bomb_x_reg   & y_a[9:4] == bomb_y_reg-1) |  // exp_1
                (bomb_y_reg != 26 & x_a[9:4] == bomb_x_reg   & y_a[9:4] == bomb_y_reg+1))); // exp_2
                

                 
wire [9:0] exp_addr = (                   x_a[9:4] == bomb_x_reg   & y_a[9:4] == bomb_y_reg  ) ? x_a[3:0] + (y_a[3:0] << 4)              : // center
                      (bomb_x_reg != 0  & x_a[9:4] == bomb_x_reg-1 & y_a[9:4] == bomb_y_reg  ) ? (15 - x_a[3:0]) + ((y_a[3:0] + 16) << 4): // exp_1
                      (bomb_x_reg != 32 & x_a[9:4] == bomb_x_reg+1 & y_a[9:4] == bomb_y_reg  ) ? x_a[3:0] + ((y_a[3:0] + 16) << 4)       : // exp_2
                      (bomb_y_reg != 0  & x_a[9:4] == bomb_x_reg   & y_a[9:4] == bomb_y_reg-1) ? x_a[3:0] + ((y_a[3:0] + 32) << 4)       : // exp_3
                      (bomb_y_reg != 26 & x_a[9:4] == bomb_x_reg   & y_a[9:4] == bomb_y_reg+1) ? x_a[3:0] + (((15 - y_a[3:0]) + 32) << 4)  // exp_4
                      : 0;
                      
// instantiate bomb sprite ROM
bomb_dm bomb_dm_unit(.a((x_a[3:0]) + {y_a[3:0], 4'd0}), .spo(bomb_rgb));

// instantiate explosions sprite ROM
explosions_br exp_br_unit(.clka(clk), .ena(1'b1), .addra(exp_addr), .douta(exp_rgb));

// assign explosion block map write address to output
assign block_w_addr = exp_block_addr_reg;

// assign block map write enable to output
assign block_we = block_we_reg;

endmodule