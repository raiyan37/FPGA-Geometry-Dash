`default_nettype none

module vga_demo(CLOCK_50, SW, KEY, PS2_CLK, PS2_DAT, LEDR, 
                HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, 
                VGA_R, VGA_G, VGA_B,
				VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
	
	parameter RESOLUTION = "640x480";
    parameter nX = (RESOLUTION == "640x480") ? 10 : ((RESOLUTION == "320x240") ? 9 : 8);
	parameter nY = (RESOLUTION == "640x480") ? 9 : ((RESOLUTION == "320x240") ? 8 : 7);

    // FSM States
    parameter A = 3'b000, B = 3'b001, C = 3'b010, D = 3'b011, E = 3'b100, F = 3'b101;

	input wire CLOCK_50;	
	input wire [9:0] SW;
	input wire [3:0] KEY;
	output wire [9:0] LEDR;
    
    output wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;

	output wire [7:0] VGA_R, VGA_G, VGA_B;
	output wire VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;
	
	inout wire PS2_CLK, PS2_DAT;
	
    wire        ps2_key_pressed;   
    wire [7:0]  ps2_key_data;      
    wire [7:0]  last_data_received; 
	
	PS2_Demo demo1 (CLOCK_50, KEY, PS2_CLK, PS2_DAT,last_data_received, ps2_key_pressed, ps2_key_data);

    // Spacebar decoding logic
    reg spacebar_down   = 1'b0; 
    reg spacebar_press  = 1'b0; 
    reg saw_break       = 1'b0; 

    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) begin
            spacebar_down  <= 1'b0;
            spacebar_press <= 1'b0;
            saw_break      <= 1'b0;
        end else begin
            spacebar_press <= 1'b0; 
            if (ps2_key_pressed) begin
                case (ps2_key_data)
                    8'hF0: saw_break <= 1'b1;     
                    8'h29: begin // Space
                        if (saw_break) begin
                            spacebar_down <= 1'b0;
                            saw_break     <= 1'b0;
                        end else begin
                            spacebar_down  <= 1'b1;
                            spacebar_press <= 1'b1; 
                        end
                    end
                    default: if (saw_break) saw_break <= 1'b0;
                endcase
            end
        end
    end
		
    // Object Wires
	wire [nX-1:0] O1_x, O2_x, O3_x, O4_x; 
	wire [nY-1:0] O1_y, O2_y, O3_y, O4_y;
	wire [8:0]    O1_color, O2_color, O3_color, O4_color;
    wire          O1_write, O2_write, O3_write, O4_write;
	wire [nX-1:0] O1_base_x, O3_base_x; 
	wire [nY-1:0] O1_base_y, O3_base_y;
    
    // Multiplexer Wires
	reg [nX-1:0] MUX_x;
	reg [nY-1:0] MUX_y;
	reg [8:0]    MUX_color;
    reg          MUX_write;
    
    // Arbitration Wires
    wire req1, req2, req3, req4; 
    reg  gnt1, gnt2, gnt3, gnt4; 
    reg [2:0] y_Q, Y_D;  
	
    wire Resetn, faster, slower, set_color;
	wire jump;
	reg game_started; 
	 
	always@(posedge CLOCK_50) begin 
		if(!Resetn)
			game_started <= 1'b0; 
		else if(VGA_SYNC_N) 
			game_started <= 1'b1; 
	end 
	 
    // Hit Detection
	wire overlap_x = (O3_base_x <= O1_base_x + 40) && (O3_base_x + 40 >= O1_base_x); 
	wire overlap_y = (O3_base_y <= O1_base_y + 40) && (O3_base_y + 60 >= O1_base_y); 
	wire hit = overlap_x && overlap_y && game_started; 

    assign Resetn = KEY[3];
	 
    // Objects use this reset (stops them on hit)
	wire global_reset = Resetn & ~hit; 
	 
    sync S1 (spacebar_press, Resetn, CLOCK_50, jump);
	
    // arbitration fsm
    always @ (*)
        case (y_Q)
            A:  if (req1) Y_D = B;          // Draw Object 1 (Player)
                else if (req2) Y_D = C;     // Draw Object 2 (Unused)
                else if (req3) Y_D = D;     // Draw Object 3 (Obstacle)
                else if (req4) Y_D = E;     // Draw Object 4 (GAME OVER TEXT)
                else Y_D = A;
            
            B:  if (req1) Y_D = B;          
                else Y_D = A;
            
            C:  if (req2) Y_D = C;          
                else Y_D = A;
            
            D:  if (req3) Y_D = D;          
                else Y_D = A;
                
            E:  if (req4) Y_D = E;          
                else Y_D = A;

            default:  Y_D = A;
        endcase

    // VGA mux
    always @ (*)
    begin
        gnt1 = 1'b0; gnt2 = 1'b0; gnt3 = 1'b0; gnt4 = 1'b0;
        MUX_write = 1'b0;
        MUX_x = O1_x; MUX_y = O1_y; MUX_color = O1_color;
        
        case (y_Q)
            A:  ; // Idle
            B:  begin gnt1 = 1'b1; MUX_write = O1_write; 
                      MUX_x = O1_x; MUX_y = O1_y; MUX_color = O1_color; end
            C:  begin gnt2 = 1'b1; MUX_write = O2_write; 
                      MUX_x = O2_x; MUX_y = O2_y; MUX_color = O2_color; end
            D:  begin gnt3 = 1'b1; MUX_write = O3_write; 
                      MUX_x = O3_x; MUX_y = O3_y; MUX_color = O3_color; end
            E:  begin gnt4 = 1'b1; MUX_write = O4_write; 
                      MUX_x = O4_x; MUX_y = O4_y; MUX_color = O4_color; end
        endcase
    end

    always @(posedge CLOCK_50)
        if (Resetn == 0)   
            y_Q <= A;
        else
            y_Q <= Y_D;

    // OBJECT INSTANTIATIONS

    // Object 1: Player
    object O1 (global_reset, CLOCK_50, gnt1, !SW[9], 1'b1, 9'b111111000, faster, slower, req1, 
               O1_x, O1_y, O1_color, O1_write, jump, O1_base_x, O1_base_y);
        defparam O1.nX = nX;
        defparam O1.nY = nY;
        defparam O1.IS_BLOCK = 1; 

    // Object 3: Obstacle
    object O3 (global_reset, CLOCK_50, gnt3, 1'b0, 1'b1, 9'b111010000, 1'b0, 1'b0, req3, 
               O3_x, O3_y, O3_color, O3_write, 1'b0, O3_base_x, O3_base_y);
        defparam O3.X_INIT = 10'd640;  
        defparam O3.Y_INIT = 9'd340;   
        defparam O3.XDIM = 40;         
        defparam O3.YDIM = 60;
        defparam O3.IS_BLOCK = 0;      
        defparam O3.IS_STATIC = 0;     
        defparam O3.MOVE_LEFT = 1;     
        defparam O3.KK = 16;           
		  
    // Object 4: GAME OVER Text
    game_over_sprite O4 (
        .clk(CLOCK_50),
        .resetn(Resetn),     // Uses reset (KEY3)
        .trigger_draw(hit),  // Draws when hit happens
        .gnt(gnt4),
        .req(req4),
        .VGA_x(O4_x),
        .VGA_y(O4_y),
        .VGA_color(O4_color),
        .VGA_write(O4_write)
    );

    vga_adapter VGA (
		.resetn(KEY[0]),
		.clock(CLOCK_50),
		.color(MUX_color),
		.x(MUX_x),
		.y(MUX_y),
		.write(MUX_write),
		.VGA_R(VGA_R),
		.VGA_G(VGA_G),
		.VGA_B(VGA_B),
		.VGA_HS(VGA_HS),
		.VGA_VS(VGA_VS),
		.VGA_BLANK_N(VGA_BLANK_N),
		.VGA_SYNC_N(VGA_SYNC_N),
		.VGA_CLK(VGA_CLK));
		defparam VGA.BACKGROUND_IMAGE = ".//background.mif";


    // game elapsed time logic

    reg [25:0] rate_divider; 
    reg [3:0]  digit_ones, digit_tens, digit_hundreds;
    reg        game_over_flag;

    always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn)
            game_over_flag <= 1'b0;
        else if (hit)
            game_over_flag <= 1'b1;
    end

    always @(posedge CLOCK_50 or negedge Resetn) begin
        if (!Resetn) begin
            rate_divider   <= 26'd0;
            digit_ones     <= 4'd0;
            digit_tens     <= 4'd0;
            digit_hundreds <= 4'd0;
        end
        else begin
            if (!game_over_flag && !hit) begin
                if (rate_divider == 26'd49_999_999) begin
                    rate_divider <= 26'd0;
                    if (digit_ones == 4'd9) begin
                        digit_ones <= 4'd0;
                        if (digit_tens == 4'd9) begin
                            digit_tens <= 4'd0;
                            if (digit_hundreds != 4'd9)
                                digit_hundreds <= digit_hundreds + 1'b1;
                        end
                        else digit_tens <= digit_tens + 1'b1;
                    end
                    else digit_ones <= digit_ones + 1'b1;
                end
                else rate_divider <= rate_divider + 1'b1;
            end
        end
    end

    hex7seg d0(digit_ones, HEX0);       
    hex7seg d1(digit_tens, HEX1);       
    hex7seg d2(digit_hundreds, HEX2);   
    assign HEX3 = 7'b1111111; 
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;
    assign LEDR[9:0] = 10'b0;

endmodule

// game over sprite drawing

module game_over_sprite(
    input wire clk,
    input wire resetn,
    input wire trigger_draw, // Connect to 'hit' signal
    input wire gnt,
    output reg req,
    output wire [9:0] VGA_x,
    output wire [8:0] VGA_y,
    output wire [8:0] VGA_color,
    output wire VGA_write
);

    parameter START_X = 10'd200;
    parameter START_Y = 9'd200;
    parameter WIDTH   = 10'd240; 
    parameter HEIGHT  = 9'd40;   

    reg [9:0] current_x;
    reg [8:0] current_y;

    // State Machine
    parameter S_IDLE    = 2'd0;
    parameter S_DRAW    = 2'd1;
    parameter S_ERASE   = 2'd2;
    
    reg [1:0] state;
    
    // Track what is currently on screen to avoid redundant drawing
    reg text_is_visible; 

    // Logic: 
    // 1. If 'trigger_draw' is TRUE but we haven't drawn yet -> Go to S_DRAW.
    // 2. If 'trigger_draw' is FALSE but text is still visible (Reset happened) -> Go to S_ERASE.
    
    always @(posedge clk) begin
        if (!resetn) begin
            state <= S_IDLE;
            req <= 0;
            text_is_visible <= 1; // Trick: Assume text IS visible on reset, so we force an Erase immediately.
            current_x <= 0;
            current_y <= 0;
        end 
        else begin
            case (state)
                S_IDLE: begin
                    current_x <= 0;
                    current_y <= 0;
                    req <= 0;
                    
                    if (trigger_draw && !text_is_visible) begin
                        state <= S_DRAW;
                        req <= 1;
                    end
                    else if (!trigger_draw && text_is_visible) begin
                        state <= S_ERASE; // Hit signal lost (Reset), but text remains? ERASE IT.
                        req <= 1;
                    end
                end

                S_DRAW: begin
                    req <= 1; // Hold bus request
                    if (gnt) begin
                        // Increment Counters
                        if (current_x == WIDTH) begin
                            current_x <= 0;
                            if (current_y == HEIGHT) begin
                                // Done Drawing
                                state <= S_IDLE;
                                text_is_visible <= 1; // Mark as "Shown"
                                req <= 0;
                            end else begin
                                current_y <= current_y + 1'b1;
                            end
                        end else begin
                            current_x <= current_x + 1'b1;
                        end
                    end
                end

                S_ERASE: begin
                    req <= 1; // Hold bus request
                    if (gnt) begin
                        // Increment Counters
                        if (current_x == WIDTH) begin
                            current_x <= 0;
                            if (current_y == HEIGHT) begin
                                // Done Erasing
                                state <= S_IDLE;
                                text_is_visible <= 0; // Mark as "Hidden"
                                req <= 0;
                            end else begin
                                current_y <= current_y + 1'b1;
                            end
                        end else begin
                            current_x <= current_x + 1'b1;
                        end
                    end
                end
            endcase
        end
    end

    // Output Coordinates
    assign VGA_x = START_X + current_x;
    assign VGA_y = START_Y + current_y;

    // Color Logic
    wire is_text_pixel;
    
    // If we are in S_DRAW, we send White (if text pixel).
    // If we are in S_ERASE, we send Black (always).
    assign VGA_color = (state == S_DRAW && is_text_pixel) ? 9'b111111111 : 9'b000000000;
    
    // Write Enable: Only write if we are actively Drawing or Erasing, AND we have the grant.
    assign VGA_write = gnt && ((state == S_DRAW && is_text_pixel) || (state == S_ERASE));

    // Font Logic (Text Bitmap)
    wire [9:0] font_x = current_x >> 2; 
    wire [8:0] font_y = current_y >> 2; 
    reg pixel_on;
	
	// used generative AI for this 
    always @(*) begin
        pixel_on = 0;
        if (font_y < 8) begin
            if (font_x >= 0 && font_x <= 4) begin // G
                if (font_y == 0 || font_y == 6 || (font_x == 0 && font_y > 0 && font_y < 6) || (font_x == 4 && font_y > 3) || (font_y == 3 && font_x > 2)) pixel_on = 1;
            end
            else if (font_x >= 6 && font_x <= 10) begin // A
                if (font_y == 0 || font_x == 6 || font_x == 10 || font_y == 3) pixel_on = 1;
            end
            else if (font_x >= 12 && font_x <= 16) begin // M
                if (font_x == 12 || font_x == 16 || (font_y == font_x - 12 && font_x <= 14) || (font_y == 16 - font_x && font_x > 14)) pixel_on = 1;
            end
            else if (font_x >= 18 && font_x <= 22) begin // E
                if (font_x == 18 || font_y == 0 || font_y == 3 || font_y == 6) pixel_on = 1;
            end
            else if (font_x >= 27 && font_x <= 31) begin // O
                if (font_y == 0 || font_y == 6 || font_x == 27 || font_x == 31) pixel_on = 1;
            end
            else if (font_x >= 33 && font_x <= 37) begin // V
                if ((font_x == 33 && font_y < 5) || (font_x == 37 && font_y < 5) || (font_y >= 5 && font_x == 35)) pixel_on = 1;
            end
            else if (font_x >= 39 && font_x <= 43) begin // E
                if (font_x == 39 || font_y == 0 || font_y == 3 || font_y == 6) pixel_on = 1;
            end
            else if (font_x >= 45 && font_x <= 49) begin // R
                if (font_x == 45 || font_y == 0 || font_y == 3 || (font_x == 49 && font_y < 3) || (font_y > 3 && font_x == font_y + 42)) pixel_on = 1;
            end
        end
    end
    assign is_text_pixel = pixel_on;
endmodule

// helper modules
module sync(D, Resetn, Clock, Q);
    input wire D;
    input wire Resetn, Clock;
    output reg Q;
    reg Qi; 
    always @(posedge Clock)
        if (Resetn == 0) begin Qi <= 1'b0; Q <= 1'b0; end
        else begin Qi <= D; Q <= Qi; end
endmodule

module regn(R, Resetn, E, Clock, Q);
    parameter n = 8;
    input wire [n-1:0] R;
    input wire Resetn, E, Clock;
    output reg [n-1:0] Q;
    always @(posedge Clock)
        if (Resetn == 0) Q <= 'b0;
        else if (E) Q <= R;
endmodule

module ToggleFF(T, Resetn, Clock, Q);
    input wire T, Resetn, Clock;
    output reg Q;
    always @(posedge Clock)
        if (!Resetn) Q <= 1'b0;
        else if (T) Q <= ~Q;
endmodule

module UpDn_count (R, Clock, Resetn, E, L, UpDn, Q);
    parameter n = 8;
    input wire [n-1:0] R;
    input wire Clock, Resetn, E, L, UpDn;
    output reg [n-1:0] Q;
    always @ (posedge Clock)
        if (Resetn == 0) Q <= 0;
        else if (L == 1) Q <= R;
        else if (E)
            if (UpDn == 1) Q <= Q + 1'b1;
            else Q <= Q - 1'b1;
endmodule

module Up_count (Clock, Resetn, Q);
    parameter n = 8;
    input wire Clock, Resetn;
    output reg [n-1:0] Q;
    always @ (posedge Clock)
        if (Resetn == 0) Q <= 'b0;
        else Q <= Q + 1'b1;
endmodule

module object (Resetn, Clock, gnt, sel, set_color, new_color, faster, slower, req,  
               VGA_x, VGA_y, VGA_color, VGA_write, jump, base_x, base_y);
	
    parameter IS_BLOCK = 0; 
	parameter IS_STATIC = 0;
    parameter MOVE_LEFT = 0; 
    parameter nX = 10;
    parameter nY = 9;
    parameter XSCREEN = 640;
    parameter YSCREEN = 480;
    parameter XDIM = XSCREEN>>4, YDIM = YSCREEN>>4; 
    parameter X_INIT = 10'd80;
    parameter Y_INIT = 9'd370;
    parameter KK = 16; 
    parameter MM = 8;  
    parameter A = 4'b0000, B = 4'b0001, C = 4'b0010, D = 4'b0011,
              E = 4'b0100, F = 4'b0101, G = 4'b0110, H = 4'b0111,
              I = 4'b1000, J = 4'b1001, K = 4'b1010, L = 4'b1011;
				  
	input wire jump; 
    input wire Resetn, Clock;
    input wire gnt, sel, set_color, faster, slower;   
    input wire [8:0] new_color; 
    output reg req; 
	output wire [nX-1:0] VGA_x; 
	output wire [nY-1:0] VGA_y;  
	output reg [8:0] VGA_color; 
    output wire VGA_write;       
	output wire [nX-1:0] base_x;
	output wire [nY-1:0] base_y; 

	wire [nX-1:0] X, XC, X0;   
	wire [nY-1:0] Y, YC, Y0;    
	wire [8:0] the_color, color;    
    wire [KK-1:0] slow;         
    reg Lx, Ly, Ey, Lxc, Lyc, Exc, Eyc, Ex; 
    wire sync, Ydir;    
    reg erase, Tdir;    
    reg [3:0] y_Q, Y_D; 
    reg write;          

    assign X0 = X_INIT;
    assign Y0 = Y_INIT;
    parameter ALT = 9'b0;   
    
    UpDn_count U2 (X0, Clock, Resetn, Ex, Lx, ~MOVE_LEFT, X);    
        defparam U2.n = nX;                                        

    UpDn_count U1 (Y0, Clock, Resetn, Ey, Ly, Ydir, Y);      
        defparam U1.n = nY;

    assign the_color = color == 9'b0 ? 9'b111111111 : new_color;
    regn UC (the_color, Resetn, (sel && set_color) | (color == 9'b0), Clock, color); 
        defparam UC.n = 9;

    UpDn_count U3 ({nX{1'd0}}, Clock, Resetn, Exc, Lxc, 1'b1, XC); 
        defparam U3.n = nX;
    UpDn_count U4 ({nY{1'd0}}, Clock, Resetn, Eyc, Lyc, 1'b1, YC); 
        defparam U4.n = nY;

    Up_count U6 (Clock, Resetn, slow);  
        defparam U6.n = KK;
    assign sync = (slow  == {KK{1'b1}});

    ToggleFF U7 (Tdir, Resetn, Clock, Ydir);        

    assign VGA_x = X + XC;                          
    assign VGA_y = Y + YC;                          
    
    wire [8:0] textured_color;
    wire is_border_x = (XC < 2) || (XC >= XDIM-2);
    wire is_border_y = (YC < 2) || (YC >= YDIM-2);
    wire is_border = is_border_x || is_border_y;
    
    wire is_eye_left = (XC >= 10 && XC <= 14) && (YC >= 12 && YC <= 16);
    wire is_eye_right = (XC >= 25 && XC <= 29) && (YC >= 12 && YC <= 16);
    wire is_mouth = (YC >= 28 && YC <= 32) && (XC >= 8 && XC <= 31) && 
                    ((YC == 28) || (YC == 32) || (XC == 8) || (XC == 31));
    wire is_smile_curve = (YC >= 25 && YC <= 33) && 
                          ((XC >= 10 && XC <= 12 && YC >= 30) || 
                           (XC >= 27 && XC <= 29 && YC >= 30));
    
    wire brick_h_line = (YC[3:0] == 4'd0) || (YC[3:0] == 4'd15);
    wire brick_v_line = ((YC[4] == 1'b0) && (XC[3:0] == 4'd0)) || 
                        ((YC[4] == 1'b1) && (XC[3:0] == 4'd8));
    wire is_brick_line = brick_h_line || brick_v_line;
    wire is_brick_shadow = (XC[2:0] >= 3'd6) && (YC[2:0] >= 3'd6);
    
    generate
        if (IS_BLOCK) begin
            assign textured_color = is_border ? 9'b000000000 :  
                                   is_eye_left ? 9'b000000000 : 
                                   is_eye_right ? 9'b000000000 :
                                   is_mouth ? 9'b000000000 :    
                                   is_smile_curve ? 9'b000000000 :
                                   9'b111111000;                 
        end else begin
            assign textured_color = is_border ? 9'b000000000 :  
                                   is_brick_line ? 9'b101000000 : 
                                   is_brick_shadow ? 9'b110001000 : 
                                   9'b111010000;                  
        end
    endgenerate
    
    always @(*) begin
        if (erase) VGA_color = ALT;
        else VGA_color = textured_color;
    end
    assign VGA_write = write;                      

	assign base_x = X; 
	assign base_y = Y; 
	 
    reg jumping;
    always @(posedge Clock) begin
    if (~Resetn) jumping <= 1'b0;
    else begin
        if (jump && (Y == 9'd370)) jumping <= 1'b1;
        else if (jumping && (Y == 9'd370) && (Ydir == 1'b1)) jumping <= 1'b0; 
                    end
                end
    
    always @ (*)
        case (y_Q)
            A:  Y_D = B;                        
            B:  if (XC != XDIM-1) Y_D = B;      
                else Y_D = C;
            C:  if (YC != YDIM-1) Y_D = B;
                else Y_D = D;
            D:  if (!sync) Y_D = D;             
                else Y_D = E;
            E:  if (!gnt) Y_D = E;              
                else Y_D = F;
            F:  if (XC != XDIM-1) Y_D = F;      
                else Y_D = G;
            G:  if (YC != YDIM-1) Y_D = F;
                else Y_D = H;
            H:  Y_D = I;                        
            I:  Y_D = J;
            J:  if (XC != XDIM-1) Y_D = J;      
                else Y_D = K;
            K:  if (YC != YDIM-1) Y_D = J;
                else Y_D = L;
            L:  Y_D = D;
            default: Y_D = A;
        endcase

    always @ (*)
    begin
        Lx = 1'b0; Ly = 1'b0; Lxc = 1'b0; Lyc = 1'b0; Exc = 1'b0; Eyc = 1'b0; Ex = 1'b0; 
        erase = 1'b0; write = 1'b0; Ey = 1'b0; Tdir = 1'b0; req = 1'b0;
        case (y_Q)
            A:  begin Lx = 1'b1; Ly = 1'b1; Lxc = 1'b1; Lyc = 1'b1; end 
            B:  begin Exc = 1'b1; write = 1'b1; 
						if(IS_STATIC) req = 1'b1;
					 end   
            C:  begin Lxc = 1'b1; Eyc = 1'b1; 
						 if(IS_STATIC) req = 1'b1;
					 end     
            D:  if(!IS_STATIC) Lyc = 1'b1; 
            E:  if(!IS_STATIC) req = 1'b1; 
            F:  if(!IS_STATIC) begin req = 1'b1; Exc = 1'b1; erase = 1'b1; write = 1'b1; end
            G:  if(!IS_STATIC) begin req = 1'b1; Lxc = 1'b1; Eyc = 1'b1; end
            H:  if(!IS_STATIC) begin 
					req = 1'b1;
					Lyc = 1'b1; 
						if (jump && (Y == 9'd3370) && (Ydir == 1'b1)) 
							Tdir = 1'b1; 
        else if (Y == 9'd200 && (Ydir == 1'b0)) begin
            Tdir = 1'b1; 
        end
        else if (Y == 9'd370 && (Ydir == 1'b1)) begin
            Tdir = 1'b1; 
        end
        else begin
            Tdir = 1'b0;
        end
		  if(MOVE_LEFT && (X < 10'd10)) begin  
				Lx = 1'b1;  
        end
        else if(!MOVE_LEFT && (X == 0)) begin
            Lx = 1'b1;
        end
    end
            I:  if(!IS_STATIC) begin req = 1'b1; 
				if(!IS_BLOCK) begin 
						Ey <= 1'b0; 
						Ex <= 1'b1;  
					end 
				else begin 
					Ey <= jumping; 
					Ex <= 1'b0; 
					end 
				end 
            J:  if(!IS_STATIC) begin req = 1'b1; Exc = 1'b1; write = 1'b1; end
            K:  if(!IS_STATIC) begin req = 1'b1; Lxc = 1'b1; Eyc = 1'b1; end
            L:  if(!IS_STATIC) Lyc = 1'b1; 
        endcase
    end

    always @(posedge Clock)
        if (Resetn == 0) y_Q <= A;
        else y_Q <= Y_D;
endmodule

module hex7seg(hex, display);
    input [3:0] hex;
    output [6:0] display;
    reg [6:0] display;
    always @(*)
        case (hex)
            4'h0: display = 7'b1000000;
            4'h1: display = 7'b1111001;
            4'h2: display = 7'b0100100;
            4'h3: display = 7'b0110000;
            4'h4: display = 7'b0011001;
            4'h5: display = 7'b0010010;
            4'h6: display = 7'b0000010;
            4'h7: display = 7'b1111000;
            4'h8: display = 7'b0000000;
            4'h9: display = 7'b0011000;
            4'hA: display = 7'b0001000;
            4'hB: display = 7'b0000011;
            4'hC: display = 7'b1000110;
            4'hD: display = 7'b0100001;
            4'hE: display = 7'b0000110;
            4'hF: display = 7'b0001110;
        endcase
endmodule