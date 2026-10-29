// Out-of-Order Instruction Scheduling Solver (purely combinational)
//
// Idea (list scheduling, longest-tail-first):
//   1. decode every instruction and find the dependency edges (RAW/WAR/WAW)
//   2. tail[i] = latency[i] + max(tail of successors)  (longest path to the end)
//   3. issue 8 times; each time among the instructions whose predecessors are
//      all issued, pick one that is already ready at the next issue slot with
//      the biggest tail; if none is ready, pick the one that becomes ready first.
module OISS(
    input  [95:0] Inst_seq_I,
    input  [47:0] Inst_latency_I,
    output reg [23:0] Inst_order_O,
    output reg [8:0]  Ex_cycle
);

integer i, j, k;

// ---------------- decode ----------------
reg [2:0] op  [0:7];
reg [2:0] rs  [0:7];
reg [2:0] rt  [0:7];
reg [2:0] rd  [0:7];
reg [5:0] lat [0:7];
reg       wr_v  [0:7];   // instruction writes rd
reg       rs_v  [0:7];   // instruction reads rs
reg       rt_v  [0:7];   // instruction reads rt
reg       rdr_v [0:7];   // instruction reads rd (STORE)

// ---------------- dependency ----------------
reg [7:0] pred [0:7];    // pred[j][i] = 1 : i must come before j
reg       dep;

// ---------------- tail ----------------
reg [8:0] tail [0:7];
reg [8:0] max_t;

// ---------------- scheduling ----------------
reg [7:0] issued;
reg [8:0] fin   [0:7];
reg [8:0] ready [0:7];
reg [8:0] T;             // earliest cycle the next instruction can start
reg [8:0] start;
reg [8:0] max_fin;
reg       found, elig, avail_j, avail_b, better;
reg [2:0] best;

always @(*) begin
    // ----- decode -----
    for (i = 0; i < 8; i = i + 1) begin
        op[i]  = Inst_seq_I[12*i+9  +: 3];
        rs[i]  = Inst_seq_I[12*i+6  +: 3];
        rt[i]  = Inst_seq_I[12*i+3  +: 3];
        rd[i]  = Inst_seq_I[12*i    +: 3];
        lat[i] = Inst_latency_I[6*op[i] +: 6];
        wr_v[i]  = (op[i] <= 3'd4);                     // ADD SUB MUL DIV LOAD
        rs_v[i]  = (op[i] <= 3'd3) || (op[i] == 3'd6);  // ADD SUB MUL DIV BRANCH
        rt_v[i]  = (op[i] <= 3'd3) || (op[i] == 3'd6);
        rdr_v[i] = (op[i] == 3'd5);                     // STORE
    end

    // ----- dependency: pred[j][i] for i < j -----
    for (j = 0; j < 8; j = j + 1) begin
        pred[j] = 8'd0;
        for (i = 0; i < 8; i = i + 1) begin
            dep = 1'b0;
            if (i < j) begin
                // RAW : WriteSet(i) & ReadSet(j)
                if (wr_v[i] && rs_v[j]  && rd[i] == rs[j]) dep = 1'b1;
                if (wr_v[i] && rt_v[j]  && rd[i] == rt[j]) dep = 1'b1;
                if (wr_v[i] && rdr_v[j] && rd[i] == rd[j]) dep = 1'b1;
                // WAR : ReadSet(i) & WriteSet(j)
                if (wr_v[j] && rs_v[i]  && rs[i] == rd[j]) dep = 1'b1;
                if (wr_v[j] && rt_v[i]  && rt[i] == rd[j]) dep = 1'b1;
                if (wr_v[j] && rdr_v[i] && rd[i] == rd[j]) dep = 1'b1;
                // WAW : WriteSet(i) & WriteSet(j)
                if (wr_v[i] && wr_v[j]  && rd[i] == rd[j]) dep = 1'b1;
            end
            pred[j][i] = dep;
        end
    end

    // ----- tail (longest path from the start of i to the end) -----
    for (i = 7; i >= 0; i = i - 1) begin
        max_t = 9'd0;
        for (j = 0; j < 8; j = j + 1)
            if (j > i && pred[j][i] && tail[j] > max_t)
                max_t = tail[j];
        tail[i] = {3'd0, lat[i]} + max_t;
    end

    // ----- issue 8 instructions -----
    issued  = 8'd0;
    T       = 9'd0;
    max_fin = 9'd0;
    best    = 3'd0;
    Inst_order_O = 24'd0;
    for (i = 0; i < 8; i = i + 1) begin
        fin[i]   = 9'd0;
        ready[i] = 9'd0;
    end

    for (k = 0; k < 8; k = k + 1) begin
        // ready time of every instruction = max finish of its predecessors
        for (j = 0; j < 8; j = j + 1) begin
            ready[j] = 9'd0;
            for (i = 0; i < 8; i = i + 1)
                if (pred[j][i] && fin[i] > ready[j])
                    ready[j] = fin[i];
        end

        // choose the best candidate
        found = 1'b0;
        best  = 3'd0;
        for (j = 0; j < 8; j = j + 1) begin
            elig = !issued[j] && ((pred[j] & ~issued) == 8'd0);
            if (elig) begin
                if (!found) begin
                    found = 1'b1;
                    best  = j[2:0];
                end
                else begin
                    avail_j = (ready[j]    <= T);
                    avail_b = (ready[best] <= T);
                    if (avail_j != avail_b)
                        better = avail_j;
                    else if (avail_j)
                        better = (tail[j] > tail[best]);
                    else
                        better = (ready[j] < ready[best]) ||
                                 (ready[j] == ready[best] && tail[j] > tail[best]);
                    if (better) best = j[2:0];
                end
            end
        end

        start = (ready[best] > T) ? ready[best] : T;
        fin[best] = start + {3'd0, lat[best]};
        T = start + 9'd1;
        issued[best] = 1'b1;
        Inst_order_O[3*k +: 3] = best;
        if (fin[best] > max_fin) max_fin = fin[best];
    end

    Ex_cycle = max_fin;
end

endmodule
