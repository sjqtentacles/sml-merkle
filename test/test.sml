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

      (* Test 7: rootHex is the hex encoding of root *)
      val hexChars = "0123456789abcdef"
      fun toHex s =
        String.concat
          (List.map
             (fn c =>
                let val v = Char.ord c
                in String.str (String.sub (hexChars, v div 16)) ^
                   String.str (String.sub (hexChars, v mod 16))
                end)
             (String.explode s))
      val () = Harness.checkString "rootHex = toHex(root) on 4-leaf tree"
        (toHex (MerkleTree.root t4), MerkleTree.rootHex t4)
      (* single leaf "x": root = "H(x)" -> hex "48287829" *)
      val () = Harness.checkString "rootHex single leaf 'x' fixed vector"
        ("48287829", MerkleTree.rootHex t1)
      (* two leaves: root = "H(H(a)H(b))" -> hex "4828482861294828622929" *)
      val () = Harness.checkString "rootHex two-leaf fixed vector"
        ("4828482861294828622929", MerkleTree.rootHex t2)
    in
      ()
    end
end
