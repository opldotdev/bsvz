# Chronicle Upgrade Support

bsvz 0.2.0 implements the script-related behavior of the BSV Chronicle
upgrade (activation heights: mainnet 943,835, testnet 1,713,022, regtest
15,000), verified against the reference node implementation
([bitcoin-sv/bitcoin-sv](https://github.com/bitcoin-sv/bitcoin-sv), master)
and the [Chronicle spec](https://github.com/bitcoin-sv-specs/protocol/blob/master/updates/chronicle-spec.md).

## What is included

### Restored opcodes

| Opcode | Byte | Notes |
|---|---|---|
| `OP_VER` | 0x62 | Pushes the executing transaction's version (4-byte LE). |
| `OP_VERIF` / `OP_VERNOTIF` | 0x65 / 0x66 | Conditionals comparing a 4-byte stack item to the tx version. |
| `OP_SUBSTR` | 0xb3 | Renamed from `OP_NOP4`. |
| `OP_LEFT` | 0xb4 | Renamed from `OP_NOP5`. |
| `OP_RIGHT` | 0xb5 | Renamed from `OP_NOP6`. |
| `OP_2MUL` | 0x8d | `x * 2`. |
| `OP_2DIV` | 0x8e | `x / 2` (truncating). |
| `OP_LSHIFTNUM` | 0xb6 | Renamed from `OP_NOP7`. Sign-preserving numeric left shift. |
| `OP_RSHIFTNUM` | 0xb7 | Renamed from `OP_NOP8`. Sign-preserving numeric right shift, truncating toward zero. |

The legacy names remain available as enum aliases (`Opcode.OP_NOP7` etc.) and
`fromAsm` still parses the old ASM names; `toAsm` emits the new names.

### Era flags

- `ExecutionFlags.chronicle` (default `true`) mirrors the node's
  `SCRIPT_CHRONICLE` block-era flag: gates malleability relaxation and the
  `SIGHASH_CHRONICLE` bit.
- `ExecutionFlags.utxo_after_chronicle` (default `true`) mirrors
  `SCRIPT_UTXO_AFTER_CHRONICLE` (per-input UTXO age): gates the new opcodes.
- `ExecutionFlags.postChronicleBsv()` is the default profile
  (`max_script_number_length = 32_000_000`).
- `ExecutionFlags.postGenesisBsv()` now means post-Genesis *pre-Chronicle*
  (`750_000` script numbers, new opcodes off).

### Selective malleability relaxation

For transactions with `version > 1` under Chronicle rules (node
`EnforceNonMalleability`), these checks are skipped: `low_s` (high-S only),
`minimal_data`, `minimal_if`, `null_fail`, `null_dummy`, `clean_stack`,
`sig_push_only`. DER/strict-encoding checks are never relaxed. When no
transaction is attached (standalone script evaluation) the strict rules are
enforced — the conservative default.

### Original Transaction Digest (OTDA)

`SigHashType.chronicle` (0x20) selects the original (pre-BIP143) transaction
digest when combined with `forkid` (0x40 → 0x60-prefixed hashtypes). A
chronicle-bit hashtype is rejected with `IllegalChronicle` when the
`chronicle` era flag is off. A `CHECKSIG` executing in an unlocking script
under Chronicle rules signs the executed script plus the full scriptPubKey
(the node's `scriptCode += scriptPubKey` extension).

## Spec discrepancy note (upstream)

The Chronicle spec prose describes `OP_VERIF` as
`OP_VER OP_GREATERTHANOREQUAL OP_IF` (a `>=` comparison), while the reference
node implementation ([interpreter.cpp, `EvalScript`, OP_VERIF/OP_VERNOTIF
cases](https://github.com/bitcoin-sv/bitcoin-sv/blob/master/src/script/interpreter.cpp))
compares for **equality** (`std::ranges::equal` of the 4-byte LE tx version
against the stack item). The BSV wiki also documents equality. bsvz follows
the node implementation: **equality**, with non-4-byte stack items evaluating
as false. If the spec is later corrected, no bsvz change is needed; if the
node changes instead, this must be revisited.
