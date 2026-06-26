(* demo.sml - build Merkle trees over fixed leaves with a deterministic hash,
   print root hashes (hex), and generate/verify an inclusion proof. Uses the
   same simple `H(...)` hash as the test suite so the fixed root-hex vectors are
   known-correct. Deterministic: same output on every run and compiler. *)

(* A deterministic, self-contained hash: wraps its input. rootHex then renders
   the resulting bytes in hex, matching the repo's test vectors. *)
val hashFn = fn s => "H(" ^ s ^ ")"

(* Fixed root-hex vectors (cross-checked by the test suite). *)
val t1 = MerkleTree.build hashFn ["x"]
val () = print "Root hashes (hex) for fixed leaves:\n"
val () = print ("  [\"x\"]                 = " ^ MerkleTree.rootHex t1 ^ "\n")
val t2 = MerkleTree.build hashFn ["a", "b"]
val () = print ("  [\"a\",\"b\"]             = " ^ MerkleTree.rootHex t2 ^ "\n")
val t4 = MerkleTree.build hashFn ["a", "b", "c", "d"]
val () = print ("  [\"a\",\"b\",\"c\",\"d\"]     = " ^ MerkleTree.rootHex t4 ^ "\n")

(* Inclusion proof + verification for leaf index 2 ("c") of the 4-leaf tree.
   RFC-6962: leaves are hashed with domain separation via hashLeaf. *)
val idx = 2
val proof = MerkleTree.proof t4 idx
val root = MerkleTree.root t4
val sz = MerkleTree.size t4
val () = print "\nInclusion proof for leaf 2 (\"c\") of the 4-leaf tree:\n"
val () = print ("  proof length = " ^ Int.toString (List.length proof) ^ "\n")
val () = print ("  verify \"c\"   = "
                ^ Bool.toString (MerkleTree.verify hashFn (MerkleTree.hashLeaf hashFn "c") proof idx sz root) ^ "\n")
val () = print ("  verify \"z\"   = "
                ^ Bool.toString (MerkleTree.verify hashFn (MerkleTree.hashLeaf hashFn "z") proof idx sz root) ^ "\n")

