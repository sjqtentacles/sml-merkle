structure MerkleTests =
struct
  val hashFn = fn s => "H(" ^ s ^ ")"

  fun run () =
    let
      val () = Harness.section "MerkleTree"

      (* Test 1: build 4-leaf tree, root is non-empty *)
      val t4 = MerkleTree.build hashFn ["a", "b", "c", "d"]
      val () = Harness.check "4-leaf root non-empty" (MerkleTree.root t4 <> "")

      (* Test 2: proof for index 0 has length 2 *)
      val p0 = MerkleTree.proof t4 0
      val () = Harness.checkInt "proof length for 4-leaf tree" (2, List.length p0)

      (* Test 3: verify returns true for each leaf *)
      val () = Harness.check "verify leaf 0"
        (MerkleTree.verify hashFn (hashFn "a") (MerkleTree.proof t4 0) 0 (MerkleTree.root t4))
      val () = Harness.check "verify leaf 1"
        (MerkleTree.verify hashFn (hashFn "b") (MerkleTree.proof t4 1) 1 (MerkleTree.root t4))
      val () = Harness.check "verify leaf 2"
        (MerkleTree.verify hashFn (hashFn "c") (MerkleTree.proof t4 2) 2 (MerkleTree.root t4))
      val () = Harness.check "verify leaf 3"
        (MerkleTree.verify hashFn (hashFn "d") (MerkleTree.proof t4 3) 3 (MerkleTree.root t4))

      (* Test 4: verify returns false for wrong leaf value *)
      val () = Harness.check "verify wrong leaf is false"
        (not (MerkleTree.verify hashFn (hashFn "z") (MerkleTree.proof t4 0) 0 (MerkleTree.root t4)))

      (* Test 5: single element tree, root equals hashFn "x" *)
      val t1 = MerkleTree.build hashFn ["x"]
      val () = Harness.checkString "single leaf root" (hashFn "x", MerkleTree.root t1)

      (* Test 6: two elements, root equals hashFn (hashFn "a" ^ hashFn "b") *)
      val t2 = MerkleTree.build hashFn ["a", "b"]
      val expected2 = hashFn (hashFn "a" ^ hashFn "b")
      val () = Harness.checkString "two-leaf root" (expected2, MerkleTree.root t2)
    in
      ()
    end
end
