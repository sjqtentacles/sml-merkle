structure MerkleTree :> MERKLE =
struct
  datatype tree = Leaf of string | Node of tree * tree * string

  fun root (Leaf h) = h
    | root (Node (_, _, h)) = h

  fun intPow base ex =
    let fun go acc e = if e = 0 then acc else go (acc * base) (e - 1)
    in go 1 ex end

  fun nextPow2 n =
    let fun go p = if p >= n then p else go (p * 2)
    in go 1 end

  fun build hashFn items =
    let
      val safeItems = if List.null items then [""] else items
      val n = List.length safeItems
      val sz = nextPow2 n
      fun pad lst =
        if List.length lst >= sz then List.take (lst, sz)
        else
          let val last = List.nth (lst, List.length lst - 1)
          in pad (lst @ [last]) end
      val leaves = List.map (fn item => Leaf (hashFn item)) (pad safeItems)
      fun combine t1 t2 = Node (t1, t2, hashFn (root t1 ^ root t2))
      fun buildLevel ts =
        case ts of
          [] => []
        | [t] => [t]
        | t1 :: t2 :: rest => combine t1 t2 :: buildLevel rest
      fun buildTree ts =
        case ts of
          [t] => t
        | _ => buildTree (buildLevel ts)
    in
      buildTree leaves
    end

  fun proof tr idx =
    let
      fun depth (Leaf _) = 0
        | depth (Node (l, _, _)) = 1 + depth l
      (* go collects siblings top-down; we reverse for bottom-up verify *)
      fun go t i d acc =
        if d = 0 then acc
        else
          case t of
            Leaf _ => acc
          | Node (l, r, _) =>
              let val half = intPow 2 (d - 1)
              in
                if i < half
                then go l i (d - 1) (root r :: acc)
                else go r (i - half) (d - 1) (root l :: acc)
              end
      val d = depth tr
    in
      go tr idx d []
    end

  fun verify hashFn leafHash siblings idx rootHash =
    let
      fun go h [] _ = h
        | go h (sib :: rest) i =
            let
              val combined =
                if i mod 2 = 0
                then hashFn (h ^ sib)
                else hashFn (sib ^ h)
            in
              go combined rest (i div 2)
            end
    in
      go leafHash siblings idx = rootHash
    end
end
