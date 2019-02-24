module binary2bcd
    (
        input wire clk, reset,
        input wire start,
        input wire [13:0] in,
        output wire [3:0] bcd3, bcd2,
                          bcd1, bcd0,
        output wire [3:0] count,
        output wire [1:0] state
    );
    
localparam [2:0]     idle               = 3'b000,  // wait for motion timer reg to hit max val
                     shift              = 3'b001,  // move enemy in current dir 15 pixels
                     check_shift        = 3'b010,  // get random_dir from LFSR and set r_addr to block module block_map
                     add                = 3'b011,  // check if new dir is blocked by wall or pillar
                     done               = 3'b100;
                     
localparam  input_width                 = 14;

reg [2:0] bcd_state, bcd_state_next;
reg [15:0] bcd, bcd_next;
reg [13:0] bin_in, bin_in_next;
reg [3:0] shift_index, shift_index_next; 

// infer registers for FSM
always @(posedge clk, posedge reset)
    if (reset)
        begin
        bcd_state           <= idle;
        bcd                 <= 0;          
        bin_in              <= 0;
        shift_index         <= 0;
        end
    else
        begin
        bcd_state           <= bcd_state_next;
        bcd                 <= bcd_next;          
        bin_in              <= bin_in_next;
        shift_index         <= shift_index_next;
        end
 
 always @ *
    begin
    //defaults
      bcd_state_next           = bcd_state;
      bcd_next                 = bcd;          
      bin_in_next              = bin_in;
      shift_index_next         = shift_index;
      
      case (bcd_state)
      idle:         begin
                    if(start)
                        begin
                        bin_in_next = in;
                        bcd_next = 0;
                        shift_index_next = 0;
                        bcd_state_next = shift;
                        end
                    else
                        bcd_state_next = idle;
                    end
      shift:        begin
                        bcd_next = bcd_next << 1;
                        bcd_next[0] = bin_in_next[(input_width - 1)];
                        bin_in_next = bin_in_next << 1;
                        bcd_state_next = check_shift;
                    end
      check_shift:  begin
                    if (shift_index_next == (input_width - 1))
                        begin
                        bcd_state_next = done;
                        end
                    else
                        begin
                        shift_index_next = shift_index_next + 1;
                        bcd_state_next = add;
                        end
                    end
      add:          begin
                    if (bcd_next[15:12] > 4)
                        begin
                        bcd_next[15:12] = bcd_next[15:12] + 3;    
                        end
                    if (bcd_next[11:8] > 4)
                        begin
                        bcd_next[11:8] = bcd_next[11:8] + 3;
                        end
                    if (bcd_next[7:4] > 4)
                        begin
                        bcd_next[7:4] = bcd_next[7:4] + 3;
                        end
                    if( bcd_next[3:0] > 4)
                        begin
                        bcd_next[3:0] = bcd_next[3:0] + 3;
                        end
                    bcd_state_next = shift;
                    end
      done:         begin
                        bcd_state_next = idle;
                    end
      endcase
    end   
    
assign bcd0 = bcd[3:0];
assign bcd1 = bcd[7:4];
assign bcd2 = bcd[11:8];
assign bcd3 = bcd[15:12];

assign count = shift_index;
assign state = bcd_state;
     
endmodule
