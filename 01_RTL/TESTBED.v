`timescale 1ns/1ps
// Self-checking testbench: reads input.txt/output.txt, checks order legality and cycle count
module TESTBED;
reg  [95:0] seq; reg [47:0] latv;
wire [23:0] order; wire [8:0] cyc;
OISS dut(.Inst_seq_I(seq),.Inst_latency_I(latv),.Inst_order_O(order),.Ex_cycle(cyc));
integer fi,fo,n,p,i,j,k,t,bad,mask,s,f,r,mx;
reg [11:0] ins [0:7]; integer L [0:7]; integer gold, lt [0:7]; integer fin[0:7], oi, seen;
reg [11:0] x; integer ro_i[0:2], nro_i, ro_j[0:2], nro_j, a, d;
function integer w; input integer o; begin w = (o<=4); end endfunction
initial begin
  fi=$fopen("input.txt","r"); fo=$fopen("output.txt","r"); bad=0;
  t=$fscanf(fi,"%d",n);
  for(p=0;p<n;p=p+1) begin
    for(i=0;i<8;i=i+1) begin t=$fscanf(fi,"%h",x); seq[12*i+:12]=x; end
    for(i=0;i<8;i=i+1) begin t=$fscanf(fi,"%d",lt[i]); end
    for(i=0;i<8;i=i+1) latv[6*i+:6]=lt[i];
    t=$fscanf(fo,"%d",gold);
    #1;
    // check
    seen=0; mx=0;
    for(i=0;i<8;i=i+1) fin[i]=0;
    for(k=0;k<8;k=k+1) begin
      oi=order[3*k+:3]; seen=seen|(1<<oi);
      // start = max(prev+1, finish of dependency predecessors that are original-earlier)
      s=(k==0)?0:s+1;
      for(j=0;j<8;j=j+1) if(j<oi && dep_f(j,oi) && fin[j]>s) s=fin[j];
      for(j=0;j<oi;j=j+1) if(dep_f(j,oi) && !(order_pos(j) < k)) bad=bad+1000; // pred must be issued before
      f=s+lt[seq[12*oi+9+:3]]; fin[oi]=f; if(f>mx) mx=f;
    end
    if(seen!==255 || mx!==gold || cyc!==gold) begin
      bad=bad+1; $display("FAIL pattern %0d: gold=%0d dut=%0d model=%0d seen=%h",p,gold,cyc,mx,seen);
    end
  end
  if(bad==0) $display("ALL %0d PATTERNS PASS",n); else $display("%0d mismatches",bad);
  $finish;
end
function integer order_pos; input integer inst; integer q; begin
  order_pos=99; for(q=0;q<8;q=q+1) if(order[3*q+:3]==inst) order_pos=q; end endfunction
function integer dep_f; input integer i0, j0;
  reg [2:0] oi_,oj_; reg [2:0] rsi,rti,rdi,rsj,rtj,rdj; reg wi,wj,rdi_r,rdj_r,rsi_v,rsj_v; reg r_;
  begin
    oi_=seq[12*i0+9+:3]; rsi=seq[12*i0+6+:3]; rti=seq[12*i0+3+:3]; rdi=seq[12*i0+:3];
    oj_=seq[12*j0+9+:3]; rsj=seq[12*j0+6+:3]; rtj=seq[12*j0+3+:3]; rdj=seq[12*j0+:3];
    wi=(oi_<=4); wj=(oj_<=4); rsi_v=(oi_<=3||oi_==6); rsj_v=(oj_<=3||oj_==6);
    rdi_r=(oi_==5); rdj_r=(oj_==5); r_=0;
    if(wi&&rsj_v&&(rdi==rsj||rdi==rtj)) r_=1;
    if(wi&&rdj_r&&rdi==rdj) r_=1;
    if(wj&&rsi_v&&(rdj==rsi||rdj==rti)) r_=1;
    if(wj&&rdi_r&&rdj==rdi) r_=1;
    if(wi&&wj&&rdi==rdj) r_=1;
    dep_f=r_;
  end endfunction
endmodule
