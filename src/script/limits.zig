pub const default_max_script_size: usize = 10_000;

/// Maximum script-number length, in bytes, after the Chronicle upgrade: 32 MiB.
/// Source: go-sdk script/interpreter/config.go `MaxScriptNumberLengthAfterChronicle`
/// (`afterChronicleConfig.MaxScriptNumberLength`). Post-Genesis it is 750,000
/// (`afterGenesisConfig`), which is `ExecutionFlags.max_script_number_length`'s default.
pub const max_script_number_length_after_chronicle: usize = 32 * 1024 * 1024;
