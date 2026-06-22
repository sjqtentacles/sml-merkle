# sml-merkle

Merkle tree construction, root computation, and inclusion proofs in pure Standard ML

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

(* Get the Merkle root *)
val root = MerkleTree.root tree

(* ...or the root as a lowercase hex string (toHex (root tree)) *)
val rootHex = MerkleTree.rootHex tree

(* Generate an inclusion proof for leaf at index i *)
val proof = MerkleTree.proof tree 2   (* list of sibling hashes *)

(* Verify an inclusion proof *)
val leafHash = sha256 "tx3"
val valid = MerkleTree.verify sha256 leafHash proof 2 root
(* => true *)

(* Minimal example with identity hash *)
val t = MerkleTree.build (fn s => "H(" ^ s ^ ")") ["a", "b"]
val r = MerkleTree.root t
(* => "H(H(a)H(b))" *)
```

## Example

`make example` builds and runs [`examples/demo.sml`](examples/demo.sml), which
builds Merkle trees over fixed leaves with a deterministic hash, prints the root
hashes in hex, and generates/verifies an inclusion proof:

```
$ make example
Root hashes (hex) for fixed leaves:
  ["x"]                 = 48287829
  ["a","b"]             = 4828482861294828622929
  ["a","b","c","d"]     = 48284828482861294828622929482848286329482864292929

Inclusion proof for leaf 2 ("c") of the 4-leaf tree:
  proof length = 2
  verify "c"   = true
  verify "z"   = false
```

## Testing

```
make test       # MLton
make test-poly  # Poly/ML
make example    # build + run the demo
```

## License

MIT
