signature MERKLE =
sig
  datatype tree = Leaf of string | Node of tree * tree * string

  (* build a tree from a list of items; hashFn is the hash function *)
  val build  : (string -> string) -> string list -> tree
  (* extract the root hash *)
  val root   : tree -> string
  (* root hash as a lowercase hex string: rootHex t = toHex (root t) *)
  val rootHex : tree -> string
  (* return the sibling hash path for leaf at index i (0-based) *)
  val proof  : tree -> int -> string list
  (* verify a leaf is in the tree: verify hashFn leafHash proof index rootHash *)
  val verify : (string -> string) -> string -> string list -> int -> string -> bool
end
