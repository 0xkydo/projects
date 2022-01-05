include "./mimc.circom";

/*
 * IfThenElse sets `out` to `true_value` if `condition` is 1 and `out` to
 * `false_value` if `condition` is 0.
 *
 * It enforces that `condition` is 0 or 1.
 *
 */
template IfThenElse() {
    signal input condition;
    signal input true_value;
    signal input false_value;
    signal output out;
    
    condition * condition - condition === 0; 
    signal temp;
    temp <== condition * true_value;
    out <== temp + false_value * (1 - condition);
}



/*
 * SelectiveSwitch takes two data inputs (`in0`, `in1`) and produces two ouputs.
 * If the "select" (`s`) input is 1, then it inverts the order of the inputs
 * in the ouput. If `s` is 0, then it preserves the order.
 *
 * It enforces that `s` is 0 or 1.
 */
template SelectiveSwitch() {
    signal input in0;
    signal input in1;
    signal input s;
    signal output out0;
    signal output out1;

    // TODO

    component c0 = IfThenElse();
    c0.condition <== s;
    c0.true_value <== in1;
    c0.false_value <== in0;

    component c1 = IfThenElse();
    c1.condition <== s;
    c1.true_value <== in0;
    c1.false_value <== in1;

    out0 <== c0.out;
    out1 <== c1.out;

}

/*
 * Verifies the presence of H(`nullifier`, `nonce`) in the tree of depth
 * `depth`, summarized by `digest`.
 * This presence is witnessed by a Merle proof provided as
 * the additional inputs `sibling` and `direction`, 
 * which have the following meaning:
 *   sibling[i]: the sibling of the node on the path to this coin
 *               at the i'th level from the bottom.
 *   direction[i]: "0" or "1" indicating whether that sibling is on the left.
 *       The "sibling" hashes correspond directly to the siblings in the
 *       SparseMerkleTree path.
 *       The "direction" keys the boolean directions from the SparseMerkleTree
 *       path, casted to string-represented integers ("0" or "1").
 */
template Spend(depth) {
    signal input digest;
    signal input nullifier;
    signal private input nonce;
    signal private input sibling[depth];
    signal private input direction[depth];

    component leaf = Mimc2();
    leaf.in0 <== nullifier;
    leaf.in1 <== nonce;
    signal hash[depth+1];
    hash[0] <== leaf.out;

    component merkHash[depth];
    component merkSwitch[depth];

    for(var i = 0; i < depth; i++){

        merkHash[i] = Mimc2();
        merkSwitch[i] = SelectiveSwitch();

        merkSwitch[i].in0 <== hash[i];
        merkSwitch[i].in1 <== sibling[i];
        merkSwitch[i].s <== direction[i];

        merkHash[i].in0 <== merkSwitch[i].out0;
        merkHash[i].in1 <== merkSwitch[i].out1;
        
        hash[i+1] <== merkHash[i].out;

    }

    hash[depth] === digest;
}

//component main = Spend(10);
