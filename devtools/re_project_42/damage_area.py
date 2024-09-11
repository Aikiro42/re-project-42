origin = (110, 52)

points = [
  (39, 1),
  (58, 1),
  (89, 9),
  (109, 23),
  (109, 32),
  (109, 32),
  (102, 39),
  (76, 46),
  (36, 48),
  (1, 40),
]

for coord in points:
  x = coord[0] - origin[0]/2
  y = -coord[1] + origin[1]/2
  y *= -1
  print(f"[{x/8}, {y/8}],")