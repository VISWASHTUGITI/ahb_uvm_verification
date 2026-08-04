module ahb_slave_mem #(
  parameter int MEM_DEPTH  = 256,
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
)(
  input  logic                  HCLK,
  input  logic                  HRESETn,
  input  logic                  HSEL,
  input  logic [ADDR_WIDTH-1:0] HADDR,
  input  logic                  HWRITE,
  input  logic [1:0]            HTRANS,
  input  logic [2:0]            HSIZE,
  input  logic [2:0]            HBURST,
  input  logic [3:0]            HPROT,
  input  logic                  HMASTLOCK,
  input  logic                  HREADY,
  input  logic [DATA_WIDTH-1:0] HWDATA,
  output logic [DATA_WIDTH-1:0] HRDATA,
  output logic                  HREADYOUT,
  output logic [1:0]            HRESP
);

  logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];
  logic wr_en_d, rd_en_d;
  logic [ADDR_WIDTH-1:0] addr_d;
  logic [2:0] hsize_d;

  wire addr_valid = HSEL && HREADY && (HTRANS==2'b10 || HTRANS==2'b11);
  wire [$clog2(MEM_DEPTH)-1:0] waddr = addr_d[$clog2(MEM_DEPTH)+1:2];

  always_ff @(posedge HCLK or negedge HRESETn) begin
    if(!HRESETn) begin
      wr_en_d<=0; rd_en_d<=0; addr_d<='0; hsize_d<='0;
    end else begin
      wr_en_d <= addr_valid &&  HWRITE;
      rd_en_d <= addr_valid && !HWRITE;
      addr_d  <= HADDR;
      hsize_d <= HSIZE;
    end
  end

  logic [3:0] byte_en;
  always_comb begin
    case(hsize_d)
      3'b000: case(addr_d[1:0])
                2'b00:byte_en=4'b0001; 2'b01:byte_en=4'b0010;
                2'b10:byte_en=4'b0100; 2'b11:byte_en=4'b1000;
                default:byte_en=4'b0000;
              endcase
      3'b001: case(addr_d[1])
                1'b0:byte_en=4'b0011; 1'b1:byte_en=4'b1100;
                default:byte_en=4'b0000;
              endcase
      default: byte_en=4'b1111;
    endcase
  end

  always_ff @(posedge HCLK or negedge HRESETn) begin
    if(!HRESETn) begin : rst_mem
      integer i;
      for(i=0;i<MEM_DEPTH;i++) mem[i]<='0;
    end else if(wr_en_d) begin
      if(byte_en[0]) mem[waddr][ 7: 0] <= HWDATA[ 7: 0];
      if(byte_en[1]) mem[waddr][15: 8] <= HWDATA[15: 8];
      if(byte_en[2]) mem[waddr][23:16] <= HWDATA[23:16];
      if(byte_en[3]) mem[waddr][31:24] <= HWDATA[31:24];
    end
  end

  // READ DATA PHASE (combinational, proper AHB pipelining).
  // AHB 2-phase pipeline: the address is sampled during the address phase and
  // the read data is presented combinationally during the data phase (the cycle
  // after the address is sampled). So HRDATA is derived directly from the
  // registered address (addr_d) and read-enable (rd_en_d) -- NO extra registered
  // cycle on the read output. This makes the read data valid at the correct edge
  // so the master can sample it one edge after the address was presented.
  logic [DATA_WIDTH-1:0] rdata_comb;
  always_comb begin
    if (rd_en_d) rdata_comb = mem[waddr];
    else         rdata_comb = '0;
  end
  assign HRDATA = rdata_comb;

  assign HREADYOUT = 1'b1;
  assign HRESP     = 2'b00;

endmodule : ahb_slave_mem
