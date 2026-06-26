signature MERKLE =
sig
  datatype tree = Leaf of string | Node of tree * tree * string

  (* RFC-6962 domain separation. The supplied [hashFn] is applied to a
     domain-prefixed byte string:

       leaf hash  = hashFn ("\000" ^ data)
       node hash  = hashFn ("\001" ^ left ^ right)

     Trees are built with the RFC-6962 split rule (largest power of two strictly
     less than the leaf count goes left), so non-power-of-two inputs produce a
     well-defined, unbalanced tree -- NO padding/duplication of the last leaf.

     BREAKING CHANGE vs. earlier releases, which used un-prefixed hashing and
     padded to a power of two. Every root hash and proof differs. *)

  (* Hashing primitives (exposed so callers can recompute hashes for proofs). *)
  val hashLeaf : (string -> string) -> string -> string         (* hashFn ("\000" ^ d) *)
  val hashNode : (string -> string) -> string * string -> string (* hashFn ("\001"^l^r) *)

  (* build a tree from a list of items; an empty list yields a single empty
     leaf (RFC-6962's empty-tree convention is out of scope here). *)
  val build  : (string -> string) -> string list -> tree

  (* extract the root hash *)
  val root   : tree -> string
  (* root hash as a lowercase hex string: rootHex t = toHex (root t) *)
  val rootHex : tree -> string
  (* lowercase hex of an arbitrary hash string *)
  val toHex  : string -> string

  (* accessors *)
  val size    : tree -> int                 (* number of leaves *)
  val depth   : tree -> int                 (* longest root->leaf path length *)
  val leaves  : tree -> string list         (* leaf hashes, left to right *)
  val getLeaf : tree -> int -> string option (* leaf hash at index *)

  (* return the audit (sibling) path for the leaf at index i (0-based), bottom
     up. Raises Subscript if i is out of range. *)
  val proof  : tree -> int -> string list

  (* verify an audit path: verify hashFn leafHash proof index treeSize rootHash.
     Hardened: rejects a negative/out-of-range index and a proof whose length
     does not match the expected audit-path length for that index/treeSize. *)
  val verify : (string -> string) -> string -> string list -> int -> int -> string -> bool

  (* append a new item (RFC-6962 append-only growth) *)
  val append : (string -> string) -> string -> tree -> tree
  (* replace the leaf data at index i (raises Subscript if out of range) *)
  val updateLeaf : (string -> string) -> int -> string -> tree -> tree

  (* multiproofs: an audit path covering a SET of leaf indices at once. Returns
     the deduplicated sibling hashes needed, paired with their tree addresses
     so a verifier can recompute the root. *)
  val multiProof  : tree -> int list -> (int * int * string) list
  val verifyMulti : (string -> string) -> tree -> int list
                    -> (int * int * string) list -> string -> bool

  (* consistency proof between an old tree of [m] leaves and a new tree, proving
     the new tree is an append-only extension of the old one. *)
  val consistencyProof  : tree -> int -> string list
  val verifyConsistency : (string -> string)
                          -> int                 (* old size m *)
                          -> string              (* old root *)
                          -> int                 (* new size n *)
                          -> string              (* new root *)
                          -> string list         (* proof *)
                          -> bool
end
