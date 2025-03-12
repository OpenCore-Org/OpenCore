//Dual Port RAM

module dual_port_RAM(CLK,CS,WR_RD_A,WR_RD_B,ADDR_A,ADDR_B,WDATA_A,WDATA_B,RDATA_A,RDATA_B);
  
  parameter N = 4;  //No. of Address Lines
  parameter D = 16; //Depth of Memory
  parameter W = 8;  //Width of Memory
  
  input CLK,CS,WR_RD_A,WR_RD_B;
  input [N-1:0] ADDR_A,ADDR_B;
  input [W-1:0] WDATA_A,WDATA_B;
  output reg [W-1:0] RDATA_A,RDATA_B;
  
  reg [W-1:0] mem [D-1:0] /* verilator public */;
  integer i;
  
  //Port A
  always@(posedge CLK)
    begin
      if(!CS)  //chip selected
        begin
          if(WR_RD_A)
            mem[ADDR_A] <= WDATA_A;
          else
            RDATA_A <= mem[ADDR_A];
        end
    end
  
  //Port B
  always@(posedge CLK)
    begin
      if(!CS)  //chip selected
        begin
          if(WR_RD_B)
            mem[ADDR_B] <= WDATA_B;
          else
            RDATA_B <= mem[ADDR_B];
        end
    end
  
  
  endmodule
