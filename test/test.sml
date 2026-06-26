structure MerkleTests =
struct
  (* A trivial, deterministic hash so test vectors are exact. RFC-6962 domain
     separation means leaves are hashed as H("\000" ^ data) and internal nodes
     as H("\001" ^ left ^ right). *)
  val hashFn = fn s => "H(" ^ s ^ ")"

  fun lh d = MerkleTree.hashLeaf hashFn d
  fun nh (l, r) = MerkleTree.hashNode hashFn (l, r)

  fun run () =
    let
      val () = Harness.section "RFC-6962 domain separation"

      (* leaf hash includes the 0x00 prefix *)
      val () = Harness.checkString "hashLeaf prefixes 0x00"
        (hashFn ("\000" ^ "a"), MerkleTree.hashLeaf hashFn "a")
      (* node hash includes the 0x01 prefix *)
      val () = Harness.checkString "hashNode prefixes 0x01"
        (hashFn ("\001" ^ "L" ^ "R"), MerkleTree.hashNode hashFn ("L", "R"))

      (* single leaf: root = leaf hash *)
      val t1 = MerkleTree.build hashFn ["x"]
      val () = Harness.checkString "single leaf root" (lh "x", MerkleTree.root t1)

      (* two leaves: root = node(leaf a, leaf b) *)
      val t2 = MerkleTree.build hashFn ["a", "b"]
      val () = Harness.checkString "two-leaf root"
        (nh (lh "a", lh "b"), MerkleTree.root t2)

      (* ----------------------------------------------------------------- *)
      val () = Harness.section "non-power-of-two construction (no padding)"
      (* three leaves: RFC split is k=2, so tree is node(node(a,b), c) *)
      val t3 = MerkleTree.build hashFn ["a", "b", "c"]
      val expect3 = nh (nh (lh "a", lh "b"), lh "c")
      val () = Harness.checkString "three-leaf root (split 2|1)" (expect3, MerkleTree.root t3)
      val () = Harness.checkInt "three-leaf size" (3, MerkleTree.size t3)
      val () = Harness.checkInt "three-leaf depth" (2, MerkleTree.depth t3)
      (* five leaves: split is k=4 -> node(balanced4, leaf e) *)
      val t5 = MerkleTree.build hashFn ["a", "b", "c", "d", "e"]
      val four = nh (nh (lh "a", lh "b"), nh (lh "c", lh "d"))
      val expect5 = nh (four, lh "e")
      val () = Harness.checkString "five-leaf root (split 4|1)" (expect5, MerkleTree.root t5)

      (* ----------------------------------------------------------------- *)
      val () = Harness.section "accessors"
      val t4 = MerkleTree.build hashFn ["a", "b", "c", "d"]
      val () = Harness.checkInt "size 4" (4, MerkleTree.size t4)
      val () = Harness.checkInt "depth 4" (2, MerkleTree.depth t4)
      val () = Harness.checkStringList "leaves are leaf hashes in order"
        ([lh "a", lh "b", lh "c", lh "d"], MerkleTree.leaves t4)
      val () = Harness.checkString "getLeaf 2"
        (lh "c", valOf (MerkleTree.getLeaf t4 2))
      val () = Harness.check "getLeaf out of range NONE" (MerkleTree.getLeaf t4 4 = NONE)
      val () = Harness.check "getLeaf negative NONE" (MerkleTree.getLeaf t4 ~1 = NONE)

      (* ----------------------------------------------------------------- *)
      val () = Harness.section "audit proofs + verify"
      fun verifyLeaf t i d =
        MerkleTree.verify hashFn (lh d) (MerkleTree.proof t i) i (MerkleTree.size t) (MerkleTree.root t)
      val () = Harness.check "verify leaf 0 of 4" (verifyLeaf t4 0 "a")
      val () = Harness.check "verify leaf 1 of 4" (verifyLeaf t4 1 "b")
      val () = Harness.check "verify leaf 2 of 4" (verifyLeaf t4 2 "c")
      val () = Harness.check "verify leaf 3 of 4" (verifyLeaf t4 3 "d")
      (* unbalanced trees *)
      val () = Harness.check "verify leaf 2 of 3" (verifyLeaf t3 2 "c")
      val () = Harness.check "verify leaf 4 of 5" (verifyLeaf t5 4 "e")
      val () = Harness.check "verify leaf 0 of 5" (verifyLeaf t5 0 "a")
      (* a 7-leaf tree exercises every split shape *)
      val t7 = MerkleTree.build hashFn ["a","b","c","d","e","f","g"]
      val labels7 = ["a","b","c","d","e","f","g"]
      val () = Harness.check "verify all 7 leaves"
        (List.all (fn i => verifyLeaf t7 i (List.nth (labels7, i))) [0,1,2,3,4,5,6])

      (* ----------------------------------------------------------------- *)
      val () = Harness.section "verify hardening"
      val () = Harness.check "wrong leaf value rejected"
        (not (MerkleTree.verify hashFn (lh "z") (MerkleTree.proof t4 0) 0 (MerkleTree.size t4) (MerkleTree.root t4)))
      val () = Harness.check "out-of-range index rejected"
        (not (MerkleTree.verify hashFn (lh "a") (MerkleTree.proof t4 0) 9 (MerkleTree.size t4) (MerkleTree.root t4)))
      val () = Harness.check "negative index rejected"
        (not (MerkleTree.verify hashFn (lh "a") (MerkleTree.proof t4 0) ~1 (MerkleTree.size t4) (MerkleTree.root t4)))
      val () = Harness.check "wrong proof length rejected"
        (not (MerkleTree.verify hashFn (lh "a") (MerkleTree.proof t4 0 @ ["junk"]) 0 (MerkleTree.size t4) (MerkleTree.root t4)))
      val () = Harness.check "short proof rejected"
        (not (MerkleTree.verify hashFn (lh "a") [] 0 (MerkleTree.size t4) (MerkleTree.root t4)))
      val () = Harness.checkRaises "proof out of range raises" (fn () => MerkleTree.proof t4 4)

      (* ----------------------------------------------------------------- *)
      val () = Harness.section "append / updateLeaf"
      val t4' = MerkleTree.append hashFn "e" t4
      val () = Harness.checkInt "append grows size" (5, MerkleTree.size t4')
      val () = Harness.checkString "append matches rebuild"
        (MerkleTree.root t5, MerkleTree.root t4')
      val tU = MerkleTree.updateLeaf hashFn 1 "B" t4
      val () = Harness.checkString "updateLeaf matches rebuild"
        (MerkleTree.root (MerkleTree.build hashFn ["a","B","c","d"]), MerkleTree.root tU)
      val () = Harness.checkRaises "updateLeaf out of range raises"
        (fn () => MerkleTree.updateLeaf hashFn 9 "z" t4)

      (* ----------------------------------------------------------------- *)
      val () = Harness.section "multiproofs"
      val () = Harness.check "multiproof verifies a single index"
        (MerkleTree.verifyMulti hashFn t4 [2] (MerkleTree.multiProof t4 [2]) (MerkleTree.root t4))
      val () = Harness.check "multiproof verifies a set"
        (MerkleTree.verifyMulti hashFn t4 [0,2] (MerkleTree.multiProof t4 [0,2]) (MerkleTree.root t4))
      val () = Harness.check "multiproof verifies all indices"
        (MerkleTree.verifyMulti hashFn t7 [0,1,2,3,4,5,6] (MerkleTree.multiProof t7 [0,1,2,3,4,5,6]) (MerkleTree.root t7))
      val () = Harness.check "multiproof unbalanced set"
        (MerkleTree.verifyMulti hashFn t5 [1,4] (MerkleTree.multiProof t5 [1,4]) (MerkleTree.root t5))
      val () = Harness.check "multiproof wrong root rejected"
        (not (MerkleTree.verifyMulti hashFn t4 [0,2] (MerkleTree.multiProof t4 [0,2]) "bogus"))

      (* ----------------------------------------------------------------- *)
      val () = Harness.section "consistency proofs"
      val old3 = MerkleTree.build hashFn ["a","b","c"]
      val new7 = MerkleTree.build hashFn ["a","b","c","d","e","f","g"]
      val cp37 = MerkleTree.consistencyProof new7 3
      val () = Harness.check "consistency 3 -> 7"
        (MerkleTree.verifyConsistency hashFn 3 (MerkleTree.root old3) 7 (MerkleTree.root new7) cp37)
      (* power-of-two old size *)
      val old4 = MerkleTree.build hashFn ["a","b","c","d"]
      val cp47 = MerkleTree.consistencyProof new7 4
      val () = Harness.check "consistency 4 -> 7 (pow2 old)"
        (MerkleTree.verifyConsistency hashFn 4 (MerkleTree.root old4) 7 (MerkleTree.root new7) cp47)
      (* m = n is the trivial proof *)
      val () = Harness.check "consistency n -> n trivial"
        (MerkleTree.verifyConsistency hashFn 7 (MerkleTree.root new7) 7 (MerkleTree.root new7) [])
      (* a tampered old root must fail *)
      val () = Harness.check "consistency rejects wrong old root"
        (not (MerkleTree.verifyConsistency hashFn 3 "bogus" 7 (MerkleTree.root new7) cp37))
      (* a tampered new root must fail *)
      val () = Harness.check "consistency rejects wrong new root"
        (not (MerkleTree.verifyConsistency hashFn 3 (MerkleTree.root old3) 7 "bogus" cp37))
      (* growth by a single append, several sizes *)
      val () =
        let
          fun build k = MerkleTree.build hashFn (List.tabulate (k, fn i => Int.toString i))
          fun ok (m, n) =
            let val tm = build m val tn = build n
            in MerkleTree.verifyConsistency hashFn m (MerkleTree.root tm) n (MerkleTree.root tn)
                 (MerkleTree.consistencyProof tn m)
            end
        in
          Harness.check "consistency across many (m,n)"
            (List.all ok [(1,2),(1,5),(2,5),(3,8),(5,9),(6,10),(7,8),(4,8)])
        end

      (* ----------------------------------------------------------------- *)
      val () = Harness.section "hex encoding"
      val () = Harness.checkString "rootHex = toHex(root)"
        (MerkleTree.toHex (MerkleTree.root t4), MerkleTree.rootHex t4)
    in
      ()
    end
end
