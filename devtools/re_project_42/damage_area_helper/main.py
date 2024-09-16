from graphics import *
import os

def drawDamageArea(damageArea, win=GraphWin("Data", 640, 480), imageOverlay="", zoomFactor=8):
  
  if imageOverlay != "":
    img = Image(Point(0, 0), imageOverlay)
    img.move(640/2, 480/2)
    img.draw(win)

  for i in range(len(damageArea)):
    a = (damageArea[i-1][0]*zoomFactor, damageArea[i-1][1]*zoomFactor)
    b = (damageArea[i][0]*zoomFactor, damageArea[i][1]*zoomFactor)
    l = Line(Point(*a), Point(*b))
    l.move(640/2, 480/2)
    l.draw(win)
  return win

def main():    
  damageArea = [
    [0.375, 0.9375],
    [1.875, 0.9375],
    [6.75, 0.0625],
    [3.5, -0.6875],
    [-6.0, -0.8125],
    [-6.875, -0.6875],
    [-0.25, -0.1875],
    [2.125, 0.1875]
  ]
  win=drawDamageArea(damageArea, zoomFactor=16, imageOverlay="C:\Program Files (x86)\Steam\steamapps\common\Starbound\mods\RE Project 42\devtools\\re_project_42\damage_area_helper\diagonalslash.png")
  win.getMouse() # Pause to view result, otherwise the window will disappear
  win.close()

main()