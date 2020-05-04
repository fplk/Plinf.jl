(define (problem blocks-4)
  (:domain blocks)
  (:objects
    table - block
    block1 - block
    block2 - block
    block3 - block
    red - color
    green - color
    blue - color)
  (:init
    (on table block1)
    (on table block2)
    (on table block3)
    (colored table red)
    (colored block1 blue)
    (colored block2 green)
    (colored block3 red)
    (= (size table) 16)
    (= (size block1) 1)
    (= (size block2) 1)
    (= (size block3) 1)
    (= (amounton table) 3)
    (= (amounton block1) 0)
    (= (amounton block2) 0)
    (= (amounton block3) 0)
    (= (posx table) 3)
    (= (posy table) 3)
    (= (posz table) -8)
    (= (yaw table) 0)
    (= (pitch table) 0)
    (= (roll table) 0)
    (= (posx block1) 0)
    (= (posy block1) 0)
    (= (posz block1) -1)
    (= (yaw block1) 0)
    (= (pitch block1) -1)
    (= (roll block1) -1)
    (= (posx block2) 3)
    (= (posy block2) -3)
    (= (posz block2) -1)
    (= (yaw block2) 0)
    (= (pitch block2) -1)
    (= (roll block2) -1)
    (= (posx block3) -3)
    (= (posy block3) 3)
    (= (posz block3) -1)
    (= (yaw block3) 0)
    (= (pitch block3) -1)
    (= (roll block3) -1))
  (:goal (and (on table block1)
              (on block1 block2)
              (on block2 block3))))