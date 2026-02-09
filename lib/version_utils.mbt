/// Version comparison and tag parsing utilities.

/// Parse a version tag like "v1.2.3" or "1.2.3" into (major, minor, patch).
/// Returns None if the string is not a valid semver.
pub fn parse_semver(tag : String) -> (Int, Int, Int)? {
  let s = strip_v_prefix(tag)
  let parts = split_string(s, '.')
  if parts.length() != 3 {
    return None
  }
  let major = parse_int(parts[0])
  let minor = parse_int(parts[1])
  let patch = parse_int(parts[2])
  match (major, minor, patch) {
    (Some(ma), Some(mi), Some(pa)) => Some((ma, mi, pa))
    _ => None
  }
}

/// Compare two semver tuples. Returns negative if a < b, 0 if equal, positive if a > b.
pub fn compare_semver(
  a : (Int, Int, Int),
  b : (Int, Int, Int)
) -> Int {
  let (a_major, a_minor, a_patch) = a
  let (b_major, b_minor, b_patch) = b
  if a_major != b_major {
    return a_major - b_major
  }
  if a_minor != b_minor {
    return a_minor - b_minor
  }
  a_patch - b_patch
}

/// Compare two version strings. Returns true if `newer` is greater than `current`.
pub fn is_newer_version(current : String, newer : String) -> Bool {
  match (parse_semver(current), parse_semver(newer)) {
    (Some(cur), Some(new_)) => compare_semver(new_, cur) > 0
    _ => false
  }
}

/// Strip the "v" prefix from a version tag if present.
pub fn strip_v_prefix(tag : String) -> String {
  if tag.has_prefix("v") && tag.length() > 1 {
    let buf = StringBuilder::new()
    for i, ch in tag {
      if i > 0 {
        buf.write_char(ch)
      }
    }
    buf.to_string()
  } else {
    tag
  }
}

/// Split a string by a delimiter character.
fn split_string(s : String, delim : Char) -> Array[String] {
  let parts : Array[String] = []
  let buf = StringBuilder::new()
  for ch in s {
    if ch == delim {
      parts.push(buf.to_string())
      buf.reset()
    } else {
      buf.write_char(ch)
    }
  }
  parts.push(buf.to_string())
  parts
}

/// Parse an integer from a string. Returns None if not a valid integer.
fn parse_int(s : String) -> Int? {
  if s == "" {
    return None
  }
  let mut result = 0
  for ch in s {
    if ch < '0' || ch > '9' {
      return None
    }
    result = result * 10 + (ch.to_int() - '0'.to_int())
  }
  Some(result)
}
