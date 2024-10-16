from math import sin, cos, pi

def pixelCoorsToStarbound(dimensions, points):
  for coord in points:
    x = coord[0] - dimensions[0]/2
    y = -coord[1] + dimensions[1]/2
    y *= 1
    print(f"[{x/8}, {y/8}],")


def circleDamageArea(radius, segments, offset=(0,0)):
  angleIncrement = 2*pi/segments
  for i in range(segments):
    x = radius * cos(angleIncrement * i) + offset[0]
    y = radius * sin(angleIncrement * i) + offset[1]
    print(f"[{x:.2f}, {y:.2f}],")
    
if __name__ == "__main__":
  dimensions = (50, 48)
  points = [
    (49, 47),
    (49, 0),
    (20, 2),
    (0, 18),
  ]
  # pixelCoorsToStarbound(dimensions, points)
  circleDamageArea(6, 8)

