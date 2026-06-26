structure MerkleTree :> MERKLE =
struct
  datatype tree = Leaf of string | Node of tree * tree * string

  fun root (Leaf h) = h
    | root (Node (_, _, h)) = h

  local
    val hexChars = "0123456789abcdef"
  in
    fun toHex s =
      String.concat
        (List.map
           (fn c =>
              let val v = Char.ord c
              in String.str (String.sub (hexChars, v div 16)) ^
                 String.str (String.sub (hexChars, v mod 16))
              end)
           (String.explode s))
  end

  fun rootHex tr = toHex (root tr)

  (* RFC-6962 domain separation. *)
  fun hashLeaf hashFn data = hashFn ("\000" ^ data)
  fun hashNode hashFn (l, r) = hashFn ("\001" ^ l ^ r)

  (* Largest power of two STRICTLY less than n (n >= 2). This is the RFC-6962
     split point k. *)
  fun splitPoint n =
    let fun go k = if k * 2 < n then go (k * 2) else k
    in go 1 end

  (* Build a balanced-on-the-left RFC-6962 tree from a non-empty list of
     already-hashed leaves. *)
  fun buildFromLeafHashes hashFn hs =
    let
      fun go [h] = Leaf h
        | go hsx =
            let
              val n = List.length hsx
              val k = splitPoint n
              val left = List.take (hsx, k)
              val right = List.drop (hsx, k)
              val lt = go left
              val rt = go right
            in
              Node (lt, rt, hashNode hashFn (root lt, root rt))
            end
    in
      go hs
    end

  fun build hashFn items =
    let
      val safeItems = if List.null items then [""] else items
      val leafHashes = List.map (hashLeaf hashFn) safeItems
    in
      buildFromLeafHashes hashFn leafHashes
    end

  fun size (Leaf _) = 1
    | size (Node (l, r, _)) = size l + size r

  fun depth (Leaf _) = 0
    | depth (Node (l, r, _)) =
        let val dl = depth l val dr = depth r
        in 1 + (if dl > dr then dl else dr) end

  fun leaves (Leaf h) = [h]
    | leaves (Node (l, r, _)) = leaves l @ leaves r

  fun getLeaf t i =
    let val ls = leaves t
    in if i < 0 orelse i >= List.length ls then NONE
       else SOME (List.nth (ls, i))
    end

  (* Audit path for leaf [idx], bottom-up. Walks the actual (unbalanced) tree
     using the size of the left subtree to decide direction. *)
  fun proof tr idx =
    let
      val n = size tr
      val () = if idx < 0 orelse idx >= n then raise Subscript else ()
      fun go (Leaf _) _ acc = acc
        | go (Node (l, r, _)) i acc =
            let val ln = size l
            in
              (* append so the path is TOP-DOWN: head is the root-level sibling *)
              if i < ln
              then go l i (acc @ [root r])
              else go r (i - ln) (acc @ [root l])
            end
    in
      go tr idx []
    end

  (* The expected audit-path length for leaf [idx] of a tree with [treeSize]
     leaves, mirroring the [proof] descent. *)
  fun auditLength idx treeSize =
    if treeSize <= 1 then 0
    else
      let val k = splitPoint treeSize
      in
        if idx < k then 1 + auditLength idx k
        else 1 + auditLength (idx - k) (treeSize - k)
      end

  (* Recompute the root from a leaf hash and audit path. Direction at each level
     is determined by the index structure (the same split rule), NOT by parity,
     so it works for unbalanced trees. *)
  fun rootFromAudit hashFn leafHash siblings idx treeSize =
    if treeSize <= 1 then leafHash
    else
      let
        val k = splitPoint treeSize
      in
        case siblings of
          [] => leafHash  (* malformed; caller checks length *)
        | sib :: rest =>
            if idx < k
            then hashNode hashFn (rootFromAudit hashFn leafHash rest idx k, sib)
            else hashNode hashFn (sib, rootFromAudit hashFn leafHash rest (idx - k) (treeSize - k))
      end

  fun verify hashFn leafHash siblings idx treeSize rootHash =
    if idx < 0 orelse idx >= treeSize then false
    else if List.length siblings <> auditLength idx treeSize then false
    else rootFromAudit hashFn leafHash siblings idx treeSize = rootHash

  fun append hashFn item tr =
    let val ls = leaves tr
    in buildFromLeafHashes hashFn (ls @ [hashLeaf hashFn item]) end

  fun updateLeaf hashFn i item tr =
    let
      val ls = leaves tr
      val () = if i < 0 orelse i >= List.length ls then raise Subscript else ()
      val ls' = List.take (ls, i) @ [hashLeaf hashFn item] @ List.drop (ls, i + 1)
    in
      buildFromLeafHashes hashFn ls'
    end

  (* --------------------------------------------------------------------- *)
  (* Multiproofs: for a set of target leaf indices, return the sibling hashes
     needed to recompute the root, addressed by (treeSize, indexWithinNode)
     pairs so the verifier can place them. We address each contributed hash by
     (size-of-the-subtree-it-roots, left-edge-index) which uniquely identifies a
     node position in the canonical RFC-6962 layout. *)

  (* Collect, for the canonical tree of [n] leaves laid out over global indices
     [lo, lo+n), the set of "covered" subtree roots needed, given a sorted set
     of target indices [targets] (each in [lo, lo+n)). A subtree with NO targets
     contributes its root (addressed by (n, lo)); a subtree fully made of
     targets needs nothing from the prover (the verifier supplies leaves). *)
  fun mpCollect tr lo targets =
    case targets of
      [] => [(size tr, lo, root tr)]   (* no targets here: prover supplies root *)
    | _ =>
        (case tr of
           Leaf _ => []                (* a targeted leaf: verifier has it *)
         | Node (l, r, _) =>
             let
               val ln = size l
               val (lt, rt) = List.partition (fn i => i < lo + ln) targets
             in
               mpCollect l lo lt @ mpCollect r (lo + ln) rt
             end)

  fun multiProof tr indices =
    let
      val n = size tr
      val () = List.app (fn i => if i < 0 orelse i >= n then raise Subscript else ()) indices
      (* sort + dedup *)
      val sorted = ListMergeSortLike indices
    in
      mpCollect tr 0 sorted
    end
  (* simple insertion sort + dedup to stay Basis-only *)
  and ListMergeSortLike xs =
    let
      fun ins (x, []) = [x]
        | ins (x, y :: ys) =
            if x < y then x :: y :: ys
            else if x = y then y :: ys
            else y :: ins (x, ys)
    in
      List.foldr ins [] xs
    end

  (* Verify a multiproof: rebuild the root using the targeted leaf hashes
     (recomputed from the verifier's known leaves) plus the supplied sibling
     roots. The verifier passes the targets as (index, _, leafHash) too; to keep
     the signature simple we accept the proof list AND derive targets from the
     tree's actual leaves recomputation is not possible, so verifyMulti takes
     the same tree shape implicitly via [size] and the proof addresses. We
     instead recompute by walking the canonical layout, consuming either a
     proof entry (subtree with no targets) or descending. *)
  fun verifyMulti hashFn tr indices proof expectedRoot =
    let
      val n = size tr
      val targetLeaves = leaves tr  (* verifier-side known leaf hashes *)
      val sorted = ListMergeSortLike indices

      (* Find a proof entry for a given (subtreeSize, lo). *)
      fun lookup (sz, lo) =
        List.find (fn (s, l, _) => s = sz andalso l = lo) proof

      fun rebuild subSize lo targets =
        case targets of
          [] =>
            (case lookup (subSize, lo) of
               SOME (_, _, h) => SOME h
             | NONE => NONE)
        | _ =>
            if subSize = 1
            then SOME (List.nth (targetLeaves, lo))  (* targeted leaf *)
            else
              let
                val k = splitPoint subSize
                val (lt, rt) = List.partition (fn i => i < lo + k) targets
              in
                case (rebuild k lo lt, rebuild (subSize - k) (lo + k) rt) of
                  (SOME lh, SOME rh) => SOME (hashNode hashFn (lh, rh))
                | _ => NONE
              end
    in
      case rebuild n 0 sorted of
        SOME h => h = expectedRoot
      | NONE => false
    end

  (* --------------------------------------------------------------------- *)
  (* Consistency proofs (RFC-6962 section 2.1.2): prove the new tree of [n]
     leaves is an append-only extension of the old tree of [m] leaves. *)

  (* Merkle Tree Hash of a slice of already-hashed leaves. *)
  (* MTH over a tree node is just its stored hash. We do not need a slice-based
     mth for proof generation, only the tree walk below. *)

  (* Consistency proof, RFC-6962 in spirit. We emit, front-to-back:
       - first, the proof for the old subtree within the left/right child
         (recursively), then
       - the sibling hash that pairs with it at this level.
     [b] is true while the old tree exactly fills the current node (so its hash
     is implicit and supplied by the verifier as oldRoot). Verification mirrors
     this exactly, so the two are guaranteed consistent. *)
  fun subProofT m tr b =
    let val n = size tr
    in
      if m = n then (if b then [] else [root tr])
      else
        case tr of
          Leaf _ => []
        | Node (l, r, _) =>
            let val k = size l
            in
              if m <= k
              then subProofT m l b @ [root r]
              else subProofT (m - k) r false @ [root l]
            end
    end

  fun consistencyProof newTree m =
    let val n = size newTree
    in
      if m <= 0 orelse m > n then raise Subscript
      else if m = n then []
      else subProofT m newTree true
    end

  (* Reconstruct (oldRoot, newRoot) from the proof. Mirrors subProofT: the
     recursive call consumes the front of the proof; the trailing element is the
     sibling at this level. [oldSeed] is the verifier's oldRoot, used wherever
     the old subtree was implicit (b=true bottomed out). Returns NONE on a
     malformed/short proof. *)
  fun reconstruct hashFn oldSeed m n b proof =
    if m = n then
      (if b then SOME (oldSeed, oldSeed, proof)  (* old subtree implicit = oldSeed *)
       else case proof of
              h :: rest => SOME (h, h, rest)
            | [] => NONE)
    else
      let
        val k = splitPoint n
      in
        if m <= k then
          (case reconstruct hashFn oldSeed m k b proof of
             SOME (oldH, newLeftH, rest) =>
               (case rest of
                  sib :: rest' =>
                    SOME (oldH, hashNode hashFn (newLeftH, sib), rest')
                | [] => NONE)
           | NONE => NONE)
        else
          (case reconstruct hashFn oldSeed (m - k) (n - k) false proof of
             SOME (oldRightH, newRightH, rest) =>
               (case rest of
                  sib :: rest' =>
                    SOME (hashNode hashFn (sib, oldRightH),
                          hashNode hashFn (sib, newRightH),
                          rest')
                | [] => NONE)
           | NONE => NONE)
      end

  fun verifyConsistency hashFn m oldRoot n newRoot proof =
    if m <= 0 orelse m > n then false
    else if m = n then (oldRoot = newRoot andalso List.null proof)
    else
      case reconstruct hashFn oldRoot m n true proof of
        SOME (oldH, newH, []) => oldH = oldRoot andalso newH = newRoot
      | _ => false
end
