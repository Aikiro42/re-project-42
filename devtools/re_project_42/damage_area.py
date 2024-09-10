origin = (110/2, 15/2)

points = [
  (58, 0),
  (70, 0),
  (109, 7),
  (83, 13),
  (7, 14),
  (0, 13),
  (53, 9),
  (72, 6)
]

for coord in points:
  x = coord[0] - origin[0]
  y = -coord[1] + origin[1]
  print(f"[{x/8}, {y/8}],")