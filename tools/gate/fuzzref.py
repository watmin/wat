"""A transition table for the README grammar. Not a copy of hex-check's scan."""

# State names are the positions in the README: between bytes, inside a comment,
# or holding one nibble.
GROUND = "ground"
COMMENT = "comment"
HIGH = "high"
COMMENT_HIGH = "comment-high"

WS = frozenset((32, 9, 13, 10))
COMMENT_MARK = frozenset((35, 59))


def digit(byte):
    if 48 <= byte <= 57:
        return byte - 48
    if 65 <= byte <= 70:
        return byte - 55
    if 97 <= byte <= 102:
        return byte - 87
    return None


def reference(data):
    """Return (status, body). Body is the bytes decoded before a refusal."""
    state = GROUND
    pending = 0
    out = bytearray()
    for byte in data:
        if state == COMMENT or state == COMMENT_HIGH:
            if byte == 10:
                state = HIGH if state == COMMENT_HIGH else GROUND
            continue
        if byte in COMMENT_MARK:
            state = COMMENT_HIGH if state == HIGH else COMMENT
            continue
        if byte in WS:
            continue
        value = digit(byte)
        if value is None:
            return 4, bytes(out)
        if state == GROUND:
            pending = value
            state = HIGH
            continue
        out.append((pending << 4) | value)
        state = GROUND
    if state == HIGH or state == COMMENT_HIGH:
        return 5, bytes(out)
    return 0, bytes(out)
