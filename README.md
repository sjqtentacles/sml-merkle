# sml-merkle

RFC-6962-style Merkle trees in pure Standard ML: construction, root computation,
inclusion (audit) proofs, multiproofs, and consistency proofs.

## Breaking change (RFC-6962 hashing)

This release adopts **RFC-6962 domain separation** and **non-power-of-two
construction**, which changes *every* root hash and proof versus earlier
versions:

- Leaf hash: `hashFn ("\000" ^ data)` (0x00 prefix).
- Node hash: `hashFn ("\001" ^ left ^ right)` (0x01 prefix).
- Trees are split with the RFC-6962 rule — the largest power of two **strictly
  less** than the leaf count goes in the left subtree — so a 3-leaf tree is
  `node(node(a,b), c)` with **no padding/duplication** of the last leaf.

If you depended on the old un-prefixed, power-of-two-padded hashes, your stored
roots and proofs are no longer valid and must be recomputed.

## Installation

```
smlpkg add github.com/sjqtentacles/sml-merkle
smlpkg sync
```

## Usage

```sml
(* Supply any hash function: string -> string *)
val sha256 = (* your hash function, e.g. from sml-sha3 *)

(* Build a tree from a list of leaf data *)
val tree = MerkleTree.build sha256 ["tx1", "tx2", "tx3", "tx4"]

val root    = MerkleTree.root tree     (* the Merkle root *)
val rootHex = MerkleTree.rootHex tree  (* root as lowercase hex *)
val n       = MerkleTree.size tree     (* 4 *)

(* Inclusion (audit) proof for the leaf at an index. *)
val proof    = MerkleTree.proof tree 2
val leafHash = MerkleTree.hashLeaf sha256 "tx3"
val ok = MerkleTree.verify sha256 leafHash proof 2 (MerkleTree.size tree) root
(* => true; verify also rejects out-of-range indices and wrong proof lengths *)

(* Append-only growth and single-leaf updates. *)
val tree5 = MerkleTree.append sha256 "tx5" tree
val tree' = MerkleTree.updateLeaf sha256 1 "tx2b" tree

(* Multiproof: one proof covering several leaves at once. *)
val mp = MerkleTree.multiProof tree [0, 2]
val okm = MerkleTree.verifyMulti sha256 tree [0, 2] mp root

(* Consistency proof: prove tree5 is an append-only extension of tree. *)
val cp = MerkleTree.consistencyProof tree5 (MerkleTree.size tree)
val okc = MerkleTree.verifyConsistency sha256
            (MerkleTree.size tree) root
            (MerkleTree.size tree5) (MerkleTree.root tree5) cp
```

## How it works

- **Domain separation** (`hashLeaf`/`hashNode`) prevents second-preimage
  attacks where a leaf could be mistaken for an internal node.
- **Audit proofs** (`proof`/`verify`) return the sibling hashes top-down; the
  verifier recomputes the root using the same split rule, so they work for
  unbalanced (non-power-of-two) trees. `verify` is hardened to reject negative
  or out-of-range indices and proofs whose length does not match the expected
  audit-path length.
- **Multiproofs** (`multiProof`/`verifyMulti`) return the deduplicated set of
  subtree roots needed to cover a *set* of leaves, each addressed by
  `(subtreeSize, leftEdgeIndex)`; the verifier rebuilds the root from its known
  target leaves plus those siblings.
- **Consistency proofs** (`consistencyProof`/`verifyConsistency`) implement
  RFC-6962 §2.1.2: given an old size `m` and a new tree of `n` leaves, the proof
  lets a verifier reconstruct *both* the old root and the new root, confirming
  the new log is an append-only extension of the old one.

## API

| Function | Description |
| --- | --- |
| `build : (string->string) -> string list -> tree` | Build a tree (RFC-6962 layout). |
| `root / rootHex : tree -> string` | Root hash (raw / hex). |
| `toHex : string -> string` | Lowercase hex of a hash. |
| `hashLeaf / hashNode` | Domain-separated leaf / node hashing. |
| `size / depth : tree -> int` | Leaf count / height. |
| `leaves : tree -> string list` | Leaf hashes left-to-right. |
| `getLeaf : tree -> int -> string option` | Leaf hash at an index. |
| `proof : tree -> int -> string list` | Audit path (raises `Subscript` if out of range). |
| `verify : ... -> int -> int -> string -> bool` | Verify audit path (size-aware, hardened). |
| `append : ... -> string -> tree -> tree` | Append a leaf. |
| `updateLeaf : ... -> int -> string -> tree -> tree` | Replace a leaf. |
| `multiProof / verifyMulti` | Proof covering a set of leaves. |
| `consistencyProof / verifyConsistency` | Append-only extension proof. |

## Example

`make example` builds and runs [`examples/demo.sml`](examples/demo.sml), which
builds Merkle trees over fixed leaves with a deterministic `H(...)` hash, prints
the root hashes in hex, and generates/verifies an inclusion proof:

```
$ make example
Root hashes (hex) for fixed leaves:
  ["x"]                 = 4828007829
  ["a","b"]             = 4828014828006129482800622929
  ["a","b","c","d"]     = 4828014828014828006129482800622929482801482800632948280064292929

Inclusion proof for leaf 2 ("c") of the 4-leaf tree:
  proof length = 2
  verify "c"   = true
  verify "z"   = false
```

## Testing

```
make test       # MLton
make test-poly  # Poly/ML
make all-tests  # both
make example    # build + run the demo
```

44 deterministic checks cover domain separation, non-power-of-two construction,
accessors, audit proofs/verify hardening, append/updateLeaf, multiproofs, and
consistency proofs across many `(m, n)` size pairs.

## License

MIT
