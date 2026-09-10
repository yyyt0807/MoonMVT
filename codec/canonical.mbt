///|
/// Result of decoding and deterministically re-encoding an MVT document.
pub(all) struct Canonicalization {
  bytes : Bytes
  input_bytes : Int
  output_bytes : Int
  changed : Bool
} derive(Debug, Eq)

///|
/// Normalize field ordering and remove unknown protobuf fields by passing the
/// document through the typed MoonMVT model.
pub fn canonicalize(
  data : Bytes,
  limits? : @limits.DecodeLimits = @limits.DecodeLimits::standard(),
) -> Canonicalization raise @error.MvtError {
  let bytes = encode_tile(decode_tile(data, limits~))
  {
    bytes,
    input_bytes: data.length(),
    output_bytes: bytes.length(),
    changed: bytes != data,
  }
}

///|
/// Return true when input already equals MoonMVT's deterministic encoding.
pub fn is_canonical(
  data : Bytes,
  limits? : @limits.DecodeLimits = @limits.DecodeLimits::standard(),
) -> Bool raise @error.MvtError {
  !canonicalize(data, limits~).changed
}

