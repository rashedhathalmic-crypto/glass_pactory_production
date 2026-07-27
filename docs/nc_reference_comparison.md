# 129-122-03-211 NC comparison

## Remaining unavoidable differences

- Coordinates can differ in the final displayed decimal places when the source
  DXF stores rounded vertices. The generator retains the DXF's available
  precision and emits up to eight decimal places; it does not substitute
  profile-specific, workbook-fitted constants.
- Header text derives the part number from the uploaded DXF filename. A renamed
  copy of the same drawing therefore has different comment text, while its
  machining blocks remain unchanged.

There are no remaining intentional differences in pass order, wheel offsets,
entry and exit motion, contour direction, absolute/incremental transitions,
feed timing, or the 0.3 mm Z oscillation cycle.
