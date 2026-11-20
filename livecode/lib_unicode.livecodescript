script "lib_unicode"
######################################################################################
## lib_unicode (LIB_UNICODE, 19 Nov 2026): the registry of the Unicode characters we use,
## read from REGISTRY.tsv, so a character means the same thing every time it appears and
## scripts never type the character itself.
##
##    start using stack "<path>/LIB_UNICODE/livecode/lib_unicode.livecodescript"
##    set the label of button "Tools" to Unicode.Char("tools menu")   -- the gear
##    put Unicode.Meaning(tChar) into tWhat                            -- "house"
##    Mesh.Define "house", Unicode.Build(Unicode.Char("house"), 40)    -- a 3D house
##
## Works in both engines and headless: it needs nothing from Vibecode3D. A procedure
## returns a raw mesh array in the engine's own format (["count"], ["vx"][i], ["vy"][i],
## ["vz"][i], ["faces"], ["lines"]), the same thing Mesh.New/MeshBox make, so the
## engine's Mesh.Define / Mesh.Transform / Mesh.Merge take it as it is.
## Y up is NEGATIVE in the engine (as MeshPyramid and the iGame3D XT builders have it).
######################################################################################

local sRows      -- sRows[char][column]
local sByMeaning -- sByMeaning[meaning] = char
local sOrder     -- the characters in file order, one a line
local sRegistry  -- the REGISTRY.tsv being used (empty = the one next to this script)
local sLastError -- why Unicode.Build gave nothing

constant kColumns = "char code name meaning kind procedure used_in status notes"

-- the LIB_UNICODE folder (this script is in its livecode/ folder)
function Unicode.Folder
   local tPath
   put the effective filename of stack "lib_unicode" into tPath
   set the itemDel to "/"
   return item 1 to -3 of tPath
end Unicode.Folder

-- use another registry file (tests, a copy in an installed game); empty = the default
command Unicode.SetRegistry pPath
   put pPath into sRegistry
   put empty into sRows
   put empty into sByMeaning
   put empty into sOrder
end Unicode.SetRegistry

-- read REGISTRY.tsv (once; Unicode.Reload reads it again after an edit)
command Unicode.Load
   local tPath, tText, tLine, tChar, i
   if sOrder is not empty then exit Unicode.Load
   put sRegistry into tPath
   if tPath is empty then put Unicode.Folder() & "/REGISTRY.tsv" into tPath
   if there is not a file tPath then return "no registry at" && tPath
   put textDecode(url ("binfile:" & tPath), "UTF-8") into tText
   replace numToCodepoint(13) & numToCodepoint(10) with return in tText
   set the itemDel to tab
   repeat for each line tLine in tText
      if tLine is empty or char 1 of tLine is "#" then next repeat
      if item 1 of tLine is "char" and item 2 of tLine is "code" then next repeat -- the header
      put item 1 of tLine into tChar
      if tChar is empty then next repeat
      repeat with i = 1 to 9
         put item i of tLine into sRows[tChar][word i of kColumns]
      end repeat
      if sRows[tChar]["meaning"] is not empty then put tChar into sByMeaning[sRows[tChar]["meaning"]]
      put tChar & return after sOrder
   end repeat
   delete the last char of sOrder
   return empty
end Unicode.Load

command Unicode.Reload
   put empty into sOrder
   put empty into sRows
   put empty into sByMeaning
   Unicode.Load
   return the result
end Unicode.Reload

-- the character for a meaning ("house" -> the house sign); empty when there is none
function Unicode.Char pMeaning
   Unicode.Load
   return sByMeaning[pMeaning]
end Unicode.Char

-- what a character means to us; empty when it is not in the registry
function Unicode.Meaning pChar
   Unicode.Load
   return sRows[pChar]["meaning"]
end Unicode.Meaning

-- the handler that builds it in 3D (entities only); empty when there is none
function Unicode.Procedure pChar
   Unicode.Load
   return sRows[pChar]["procedure"]
end Unicode.Procedure

-- any column of a character's line: code, name, meaning, kind, procedure, used_in, status, notes
function Unicode.Field pChar, pColumn
   Unicode.Load
   return sRows[pChar][pColumn]
end Unicode.Field

-- "U+2302" worked out from the character itself (the registry's code column can be checked by it)
function Unicode.Code pChar
   local tHex
   if pChar is empty then return empty
   put toUpper(baseConvert(codepointToNum(codepoint 1 of pChar), 10, 16)) into tHex
   repeat while the number of chars of tHex < 4
      put "0" before tHex
   end repeat
   return "U+" & tHex
end Unicode.Code

-- the characters, one a line, in file order; pKind (tool, entity, mark) and pStatus
-- (used, planned, clash) narrow it, empty = all
function Unicode.List pKind, pStatus
   local tChar, tOut
   Unicode.Load
   repeat for each line tChar in sOrder
      if pKind is not empty and sRows[tChar]["kind"] is not pKind then next repeat
      if pStatus is not empty and sRows[tChar]["status"] is not pStatus then next repeat
      put tChar & return after tOut
   end repeat
   delete the last char of tOut
   return tOut
end Unicode.List

-- lines where the registry disagrees with itself: a code column that is not the character's
-- own code, or a meaning used by two characters. Empty = all good.
function Unicode.Check
   local tChar, tOut, tSeen, tMeaning
   Unicode.Load
   repeat for each line tChar in sOrder
      if sRows[tChar]["code"] is not Unicode.Code(tChar) then
         put "code" && sRows[tChar]["code"] && "but the character is" && Unicode.Code(tChar) & ":" && sRows[tChar]["meaning"] & return after tOut
      end if
      put sRows[tChar]["meaning"] into tMeaning
      if tMeaning is not empty then
         if tSeen[tMeaning] is not empty then put "meaning used twice:" && tMeaning & return after tOut
         put tChar into tSeen[tMeaning]
      end if
   end repeat
   delete the last char of tOut
   return tOut
end Unicode.Check

-- build the thing a character names: runs its procedure with pSize (its width, empty = the
-- procedure's own default) and returns the raw mesh. Empty when the character has no
-- procedure or it is not written yet: Unicode.LastError() then says which.
function Unicode.Build pChar, pSize
   local tProc
   put empty into sLastError
   put Unicode.Procedure(pChar) into tProc
   if tProc is empty then
      put "no procedure for" && Unicode.Code(pChar) && Unicode.Meaning(pChar) into sLastError
      return empty
   end if
   if tProc is not among the lines of Unicode.Written() then
      put tProc && "is planned, not written yet" into sLastError
      return empty
   end if
   dispatch function tProc to me with pSize
   return the result
end Unicode.Build

function Unicode.LastError
   return sLastError
end Unicode.LastError

-- the procedures written so far, one a line (the registry also names planned ones)
function Unicode.Written
   return "Proc.House" & return & "Proc.Car" & return & "Proc.Truck" & return & "Proc.Cloud" & return & "Proc.StormCloud" & return & "Proc.Person"
end Unicode.Written


######################################################################################
## PROCEDURES: build by math. Each takes the width first; the other sizes follow from it.
######################################################################################

-- a raw mesh (the engine's Mesh.New format, made here so this library stands alone)
private function UProc.New
   local tM
   put 0 into tM["count"]
   put empty into tM["faces"]
   put empty into tM["lines"]
   return tM
end UProc.New

private command UProc.V @pM, pX, pY, pZ
   add 1 to pM["count"]
   put pX + 0 into pM["vx"][pM["count"]]
   put pY + 0 into pM["vy"][pM["count"]]
   put pZ + 0 into pM["vz"][pM["count"]]
end UProc.V

private command UProc.F @pM, pIndices
   if pM["faces"] is empty then put pIndices into pM["faces"]
   else put return & pIndices after pM["faces"]
end UProc.F

private command UProc.L @pM, pA, pB
   if pM["lines"] is empty then put pA && pB into pM["lines"]
   else put return & pA && pB after pM["lines"]
end UProc.L

-- ⌂ house: four walls, a gable roof with its ridge front to back, a door drawn on the front.
-- Stands on y = 0 (the floor), centred on x and z, up is negative y. 10 corners, 7 faces
-- (floor, 4 walls, 2 roof slopes; front and back walls are five-sided with their gable),
-- plus the door as 3 wire lines. Winding as MeshBox's.
--   pW width (x), pH wall height, pD depth (z), pRoof roof height above the walls
--   defaults: pW 40, pH = 0.75 pW, pD = pW, pRoof = 0.5 pW
function Proc.House pW, pH, pD, pRoof
   local tM, hw, hd, tTop, tRidge, tDoorW, tDoorH, tFront
   if pW is not a number or pW <= 0 then put 40 into pW
   if pH is not a number or pH <= 0 then put pW * 0.75 into pH
   if pD is not a number or pD <= 0 then put pW into pD
   if pRoof is not a number or pRoof < 0 then put pW * 0.5 into pRoof
   put pW / 2 into hw
   put pD / 2 into hd
   put 0 - pH into tTop
   put 0 - pH - pRoof into tRidge
   put UProc.New() into tM
   -- 1-4 the floor corners, 5-8 the tops of the walls (same order), 9-10 the ridge ends
   UProc.V tM, -hw, 0, -hd
   UProc.V tM, hw, 0, -hd
   UProc.V tM, hw, 0, hd
   UProc.V tM, -hw, 0, hd
   UProc.V tM, -hw, tTop, -hd
   UProc.V tM, hw, tTop, -hd
   UProc.V tM, hw, tTop, hd
   UProc.V tM, -hw, tTop, hd
   UProc.V tM, 0, tRidge, -hd
   UProc.V tM, 0, tRidge, hd
   UProc.F tM, "1 2 3 4"      -- floor
   UProc.F tM, "5 9 6 2 1"    -- front wall and its gable (z = -depth/2)
   UProc.F tM, "4 3 7 10 8"   -- back wall and its gable
   UProc.F tM, "1 4 8 5"      -- left wall
   UProc.F tM, "6 7 3 2"      -- right wall
   UProc.F tM, "5 8 10 9"     -- left roof slope
   UProc.F tM, "9 10 7 6"     -- right roof slope
   -- the door: a quarter of the width, two thirds of the wall, a hair in front of the wall
   put pW / 8 into tDoorW
   put 0 - pH * 2 / 3 into tDoorH
   put 0 - hd - pW / 200 into tFront
   UProc.V tM, -tDoorW, 0, tFront
   UProc.V tM, -tDoorW, tDoorH, tFront
   UProc.V tM, tDoorW, tDoorH, tFront
   UProc.V tM, tDoorW, 0, tFront
   UProc.L tM, 11, 12
   UProc.L tM, 12, 13
   UProc.L tM, 13, 14
   return tM
end Proc.House


-- a flat outline (pPts: "x y" a line, in order round the edge) pushed along z from pZ1 to pZ2:
-- one closed part (sides + both caps), its corners added to pM
private command UProc.ExtrudeZ @pM, pPts, pZ1, pZ2
   local tN, tStart, tLine, k, k2, tCap1, tCap2
   put the number of lines of pPts into tN
   if tN < 3 then exit UProc.ExtrudeZ
   put pM["count"] into tStart
   repeat for each line tLine in pPts
      UProc.V pM, word 1 of tLine, word 2 of tLine, pZ1
   end repeat
   repeat for each line tLine in pPts
      UProc.V pM, word 1 of tLine, word 2 of tLine, pZ2
   end repeat
   repeat with k = 1 to tN
      put (k mod tN) + 1 into k2
      UProc.F pM, (tStart + k) && (tStart + k2) && (tStart + tN + k2) && (tStart + tN + k)
      put (tStart + k) & space after tCap1
      put (tStart + tN + tN + 1 - k) & space after tCap2
   end repeat
   UProc.F pM, word 1 to -1 of tCap1
   UProc.F pM, word 1 to -1 of tCap2
end UProc.ExtrudeZ

-- the outline of a box side (x1..x2, y1..y2) for UProc.ExtrudeZ
private function UProc.Rect pX1, pY1, pX2, pY2
   return pX1 && pY1 & return & pX2 && pY1 & return & pX2 && pY2 & return & pX1 && pY2
end UProc.Rect

-- a wheel: an octagon of radius pR at x = pX, pushed along z, a flat side standing on y = 0
private command UProc.Wheel @pM, pX, pR, pZ1, pZ2
   local tPts, k, tA, pY
   put 0 - pR * cos(pi / 8) into pY
   repeat with k = 0 to 7
      put (k * 45 + 22.5) * pi / 180 into tA
      put (pX + pR * cos(tA)) && (pY + pR * sin(tA)) & return after tPts
   end repeat
   delete the last char of tPts
   UProc.ExtrudeZ pM, tPts, pZ1, pZ2
end UProc.Wheel

-- a low ball (8 sides, 3 rings and two poles) round (pX, pY, pZ): one closed part
private command UProc.Ball @pM, pX, pY, pZ, pR
   local tTop, tFirst, r, k, tA, tB, tRing, tY, a, b, c, d
   put pM["count"] + 1 into tTop
   UProc.V pM, pX, pY - pR, pZ
   put pM["count"] + 1 into tFirst
   repeat with r = 1 to 3
      put r * 45 * pi / 180 into tB  -- from the top pole down
      put pR * sin(tB) into tRing
      put pY - pR * cos(tB) into tY
      repeat with k = 0 to 7
         put k * 45 * pi / 180 into tA
         UProc.V pM, pX + tRing * cos(tA), tY, pZ + tRing * sin(tA)
      end repeat
   end repeat
   UProc.V pM, pX, pY + pR, pZ -- the bottom pole = count
   repeat with k = 0 to 7
      put tFirst + k into a
      put tFirst + ((k + 1) mod 8) into b
      UProc.F pM, tTop && b && a
      repeat with r = 0 to 1
         put tFirst + r * 8 + k into a
         put tFirst + r * 8 + ((k + 1) mod 8) into b
         put b + 8 into c
         put a + 8 into d
         UProc.F pM, a && b && c && d
      end repeat
      put tFirst + 16 + k into a
      put tFirst + 16 + ((k + 1) mod 8) into b
      UProc.F pM, a && b && pM["count"]
   end repeat
end UProc.Ball

-- car (the emoji car; there is none in the BMP): a body, a cabin, four wheels.
-- pW = its length along x, the front at +x; stands on y = 0, up is negative y.
-- 6 closed parts: body box, cabin (a trapezoid pushed along z), 4 octagon wheels.
function Proc.Car pW
   local tM, L, hw, r
   if pW is not a number or pW <= 0 then put 40 into pW
   put pW into L
   put L * 0.23 into hw            -- half its width (z)
   put L * 0.13 into r             -- wheel radius
   put UProc.New() into tM
   UProc.ExtrudeZ tM, UProc.Rect(-L / 2, -L * 0.12, L / 2, -L * 0.36), -hw, hw
   UProc.ExtrudeZ tM, (-L * 0.28) && (-L * 0.36) & return & (L * 0.18) && (-L * 0.36) & return \
         & (L * 0.08) && (-L * 0.58) & return & (-L * 0.2) && (-L * 0.58), -hw * 0.85, hw * 0.85
   UProc.Wheel tM, -L * 0.31, r, -hw - L * 0.02, -hw + L * 0.06
   UProc.Wheel tM, L * 0.31, r, -hw - L * 0.02, -hw + L * 0.06
   UProc.Wheel tM, -L * 0.31, r, hw - L * 0.06, hw + L * 0.02
   UProc.Wheel tM, L * 0.31, r, hw - L * 0.06, hw + L * 0.02
   return tM
end Proc.Car

-- truck: a cargo box behind a cab, on a chassis, four wheels. pW = its length along x,
-- the cab at +x; stands on y = 0, up is negative y. 7 closed parts.
function Proc.Truck pW
   local tM, L, hw, r
   if pW is not a number or pW <= 0 then put 40 into pW
   put pW into L
   put L * 0.21 into hw
   put L * 0.12 into r
   put UProc.New() into tM
   UProc.ExtrudeZ tM, UProc.Rect(-L / 2, -L * 0.12, L / 2, -L * 0.18), -hw * 0.9, hw * 0.9    -- chassis
   UProc.ExtrudeZ tM, UProc.Rect(-L / 2, -L * 0.18, L * 0.16, -L * 0.62), -hw, hw            -- cargo box
   UProc.ExtrudeZ tM, (L * 0.2) && (-L * 0.18) & return & (L / 2) && (-L * 0.18) & return \
         & (L / 2) && (-L * 0.36) & return & (L * 0.4) && (-L * 0.5) & return & (L * 0.2) && (-L * 0.5), -hw, hw   -- cab
   UProc.Wheel tM, -L * 0.32, r, -hw - L * 0.02, -hw + L * 0.05
   UProc.Wheel tM, L * 0.34, r, -hw - L * 0.02, -hw + L * 0.05
   UProc.Wheel tM, -L * 0.32, r, hw - L * 0.05, hw + L * 0.02
   UProc.Wheel tM, L * 0.34, r, hw - L * 0.05, hw + L * 0.02
   return tM
end Proc.Truck

-- cloud: five round puffs in a row, the middle ones biggest, no randomness (the same cloud
-- every time). pW = its length along x. It floats: its bottom is pW * 1.5 above y = 0, so a
-- cloud dropped on a spot hangs in the sky over it.
function Proc.Cloud pW
   local tM
   if pW is not a number or pW <= 0 then put 40 into pW
   put UProc.New() into tM
   UProc.CloudPuffs tM, pW, pW * 1.5
   return tM
end Proc.Cloud

private command UProc.CloudPuffs @pM, pW, pHeight
   local i, tR, tX, tZ
   repeat with i = 0 to 4
      put pW * (0.15 + 0.1 * sin(pi * i / 4)) into tR
      put -pW * 0.34 + pW * 0.68 * i / 4 into tX
      if i mod 2 is 0 then put pW * 0.05 into tZ
      else put -pW * 0.05 into tZ
      UProc.Ball pM, tX, -pHeight - tR, tZ, tR
   end repeat
end UProc.CloudPuffs

-- storm cloud: the cloud with a zigzag bolt of lightning (wire lines) down to the ground
function Proc.StormCloud pW
   local tM, tFirst, k, tH
   if pW is not a number or pW <= 0 then put 40 into pW
   put pW * 1.5 into tH
   put UProc.New() into tM
   UProc.CloudPuffs tM, pW, tH
   put tM["count"] + 1 into tFirst
   UProc.V tM, 0, -tH, 0
   UProc.V tM, -pW * 0.08, -tH * 0.62, 0
   UProc.V tM, pW * 0.05, -tH * 0.58, 0
   UProc.V tM, -pW * 0.06, -tH * 0.22, 0
   UProc.V tM, pW * 0.07, -tH * 0.26, 0
   UProc.V tM, 0, 0, 0
   repeat with k = 0 to 4
      UProc.L tM, tFirst + k, tFirst + k + 1
   end repeat
   return tM
end Proc.StormCloud


######################################################################################
## 웃 PERSON: a stick figure with bones, by math or from a LIB_MOCAP stick clip
######################################################################################
-- The bones are LIB_MOCAP's 25 joints (the same names, parents and lines as its stick
-- clips), so a clip and the math move the same figure. Joints, 1-based:
--   1 Hips 2 Spine 3 Spine1 4 Spine2 5 Neck 6 Head 7 HeadTop_End
--   8 LeftShoulder 9 LeftArm 10 LeftForeArm 11 LeftHand
--   12 RightShoulder 13 RightArm 14 RightForeArm 15 RightHand
--   16 LeftUpLeg 17 LeftLeg 18 LeftFoot 19 LeftToeBase 20 LeftToe_End
--   21 RightUpLeg 22 RightLeg 23 RightFoot 24 RightToeBase 25 RightToe_End
-- A pose is the joints' points, one "x,y,z" a line, in engine units: feet on y = 0, up is
-- negative y, the figure FACES -z (like the house's door), so its left hand is at -x.
-- The mesh: one wire line a bone, the head a ball (the only closed part).
-- Scale: the car's. 40 wide is a 4.5 m car, so a person (1.75 m) is 0.4 * pW tall.

constant kPersonEdges = "1-2 2-3 3-4 4-5 5-6 6-7 4-8 8-9 9-10 10-11 4-12 12-13 13-14 14-15 1-16 16-17 17-18 18-19 19-20 1-21 21-22 22-23 23-24 24-25"
constant kPersonMotions = "stand,walk,run,wave"

-- 웃 person standing, arms a little out. pW the size (as the car's width); 0.4 * pW tall.
function Proc.Person pW
   if pW is not a number or pW <= 0 then put 40 into pW
   return Person.Mesh(Person.Pose("stand", 0, pW * 0.4), kPersonEdges, 6, 7)
end Proc.Person

function Person.Names
   return "Hips,Spine,Spine1,Spine2,Neck,Head,HeadTop_End,LeftShoulder,LeftArm,LeftForeArm,LeftHand,RightShoulder,RightArm,RightForeArm,RightHand,LeftUpLeg,LeftLeg,LeftFoot,LeftToeBase,LeftToe_End,RightUpLeg,RightLeg,RightFoot,RightToeBase,RightToe_End"
end Person.Names

-- the bones as "a-b" words (1-based joints), the same as LIB_MOCAP's edges line
function Person.Edges
   return kPersonEdges
end Person.Edges

function Person.Motions
   return kPersonMotions
end Person.Motions

-- the pose of a motion by math: pMotion stand / walk / run / wave, pPhase 0..1 through one
-- cycle (a walk cycle is two steps), pH the height. The legs swing from the hips with the
-- knees bent while a foot swings forward; the hips sit as high as the longer leg lets them,
-- so the lowest foot is always on the ground and the body bobs by itself.
function Person.Pose pMotion, pPhase, pH
   local tA, tS, tC, tHip, tKnee, tArm, tElbow, tSide, tFore, tLean, tJ, tY, tOut, i
   if pH is not a number or pH <= 0 then put 16 into pH
   if pPhase is not a number then put 0 into pPhase
   put 2 * pi * pPhase into tA
   put sin(tA) into tS
   put cos(tA) into tC
   -- angles in degrees: [1] left, [2] right. Hip and arm swing forward (+), knee bend
   -- (shin back from the thigh), elbow bend (forearm forward), side = arm raised out (0 down)
   put 0 into tLean
   switch pMotion
      case "walk"
         put 22 * tS into tHip[1]
         put -22 * tS into tHip[2]
         put 6 + 38 * max(0, tC) into tKnee[1]
         put 6 + 38 * max(0, -tC) into tKnee[2]
         put -18 * tS into tArm[1]
         put 18 * tS into tArm[2]
         put 18 into tElbow[1]
         put 18 into tElbow[2]
         put 6 into tSide[1]
         put 6 into tSide[2]
         put 3 into tLean
         break
      case "run"
         put 34 * tS into tHip[1]
         put -34 * tS into tHip[2]
         put 12 + 75 * max(0, tC) into tKnee[1]
         put 12 + 75 * max(0, -tC) into tKnee[2]
         put -38 * tS into tArm[1]
         put 38 * tS into tArm[2]
         put 85 into tElbow[1]
         put 85 into tElbow[2]
         put 10 into tSide[1]
         put 10 into tSide[2]
         put 9 into tLean
         break
      case "wave"
         -- the right arm up and out, its forearm waving over the head
         put 0 into tHip[1]
         put 0 into tHip[2]
         put 3 into tKnee[1]
         put 3 into tKnee[2]
         put 0 into tArm[1]
         put 0 into tArm[2]
         put 10 into tElbow[1]
         put 0 into tElbow[2]
         put 8 into tSide[1]
         put 140 into tSide[2]
         put 175 + 25 * tS into tFore[2]
         break
      default
         -- stand: a slow sway (breathing), the arms a little out
         put 0 into tHip[1]
         put 0 into tHip[2]
         put 3 into tKnee[1]
         put 3 into tKnee[2]
         put 2 * tS into tArm[1]
         put 2 * tS into tArm[2]
         put 10 into tElbow[1]
         put 10 into tElbow[2]
         put 9 + tS into tSide[1]
         put 9 + tS into tSide[2]
         put 1.5 * tS into tLean
   end switch
   repeat with i = 1 to 2
      if tFore[i] is empty then put tSide[i] into tFore[i]
   end repeat
   -- the legs first, in a figure 1 tall facing +z with y up (LIB_MOCAP's frame)
   UPerson.Legs tJ, tHip, tKnee, tY
   UPerson.Body tJ, item 2 of tJ[1], tLean
   UPerson.Arm tJ, 1, tArm[1], tElbow[1], tSide[1], tFore[1]
   UPerson.Arm tJ, 2, tArm[2], tElbow[2], tSide[2], tFore[2]
   -- to the engine: turned round to face -z (x and z negated), up = -y, scaled to pH
   repeat with i = 1 to 25
      put UPerson.R(-item 1 of tJ[i] * pH) & comma & UPerson.R(-item 2 of tJ[i] * pH) & comma & UPerson.R(-item 3 of tJ[i] * pH) & return after tOut
   end repeat
   delete the last char of tOut
   return tOut
end Person.Pose

-- the bone sizes, as parts of the height (a figure 1 tall)
constant kThigh = 0.245
constant kShin = 0.24
constant kAnkle = 0.045
constant kUpperArm = 0.165
constant kForearm = 0.15

private function UPerson.R pV
   return round(pV, 3)
end UPerson.R

-- a bone pointing down, swung forward by pFwd degrees and out to the side by pOut degrees
-- (pSign +1 = the left side, out = +x while facing +z); its end from pFrom, pLen long
private function UPerson.Bone pFrom, pLen, pFwd, pOut, pSign
   local tFwd, tSide
   put pFwd * pi / 180 into tFwd
   put pOut * pi / 180 into tSide
   return (item 1 of pFrom + pLen * pSign * sin(tSide)) & comma & (item 2 of pFrom - pLen * cos(tSide) * cos(tFwd)) & comma & (item 3 of pFrom + pLen * cos(tSide) * sin(tFwd))
end UPerson.Bone

private command UPerson.Legs @pJ, pHip, pKnee, @pHipY
   local tDrop, i, tSign, tBase, tKneeP, tAnkle
   -- how far each leg reaches down: the hips sit on the longer one
   put 0 into pHipY
   repeat with i = 1 to 2
      put kThigh * cos(pHip[i] * pi / 180) + kShin * cos((pHip[i] - pKnee[i]) * pi / 180) into tDrop[i]
      put max(pHipY, tDrop[i] + kAnkle) into pHipY
   end repeat
   put "0," & (pHipY + 0.01) & ",0" into pJ[1]
   repeat with i = 1 to 2
      if i is 1 then put 1 into tSign
      else put -1 into tSign
      put (i - 1) * 5 + 16 into tBase
      put (tSign * 0.055) & comma & pHipY & ",0" into pJ[tBase]
      put UPerson.Bone(pJ[tBase], kThigh, pHip[i], 0, tSign) into tKneeP
      put tKneeP into pJ[tBase + 1]
      put UPerson.Bone(tKneeP, kShin, pHip[i] - pKnee[i], 0, tSign) into tAnkle
      put tAnkle into pJ[tBase + 2]
      -- the foot stays flat: toes forward along the ground (or the swinging foot's height)
      put item 1 of tAnkle & comma & (item 2 of tAnkle - kAnkle * 0.75) & comma & (item 3 of tAnkle + 0.06) into pJ[tBase + 3]
      put item 1 of tAnkle & comma & (item 2 of tAnkle - kAnkle) & comma & (item 3 of tAnkle + 0.11) into pJ[tBase + 4]
   end repeat
end UPerson.Legs

-- spine, neck, head and shoulders from the hips, leaning forward pLean degrees
private command UPerson.Body @pJ, pHipY, pLean
   local tUp, tL, i
   put pLean * pi / 180 into tL
   -- heights above the hips: Spine, Spine1, Spine2, Neck, Head, HeadTop_End
   put "0.04,0.12,0.20,0.29,0.33,0.48" into tUp
   repeat with i = 1 to 6
      put "0," & (pHipY + item i of tUp * cos(tL)) & comma & (item i of tUp * sin(tL)) into pJ[i + 1]
   end repeat
   -- the shoulder blades and shoulders, at the top of the spine (Spine2 = joint 4)
   put 0.04 & comma & (item 2 of pJ[4] + 0.045) & comma & item 3 of pJ[4] into pJ[8]
   put 0.10 & comma & (item 2 of pJ[4] + 0.04) & comma & item 3 of pJ[4] into pJ[9]
   put -0.04 & comma & (item 2 of pJ[4] + 0.045) & comma & item 3 of pJ[4] into pJ[12]
   put -0.10 & comma & (item 2 of pJ[4] + 0.04) & comma & item 3 of pJ[4] into pJ[13]
end UPerson.Body

-- arm pWhich (1 left, 2 right) from its shoulder: elbow, then the hand (wrist)
private command UPerson.Arm @pJ, pWhich, pFwd, pElbow, pOut, pForeOut
   local tSign, tBase, tElbowP
   if pWhich is 1 then put 1 into tSign
   else put -1 into tSign
   put (pWhich - 1) * 4 + 9 into tBase
   put UPerson.Bone(pJ[tBase], kUpperArm, pFwd, pOut, tSign) into tElbowP
   put tElbowP into pJ[tBase + 1]
   put UPerson.Bone(tElbowP, kForearm, pFwd + pElbow, pForeOut, tSign) into pJ[tBase + 2]
end UPerson.Arm

-- the mesh for a pose: a wire line a bone (pEdges "a-b" words, 1-based) and the head as a
-- ball between joints pHead and pTop (the bone between them is inside it, so not drawn)
function Person.Mesh pPose, pEdges, pHead, pTop
   local tM, tLine, tE, a, b, tHx, tHy, tHz, tR
   if pEdges is empty then put kPersonEdges into pEdges
   if pHead is not a number then put 6 into pHead
   if pTop is not a number then put 7 into pTop
   put UProc.New() into tM
   set the itemDel to comma
   repeat for each line tLine in pPose
      UProc.V tM, item 1 of tLine, item 2 of tLine, item 3 of tLine
   end repeat
   repeat for each word tE in pEdges
      set the itemDel to "-"
      put item 1 of tE into a
      put item 2 of tE into b
      set the itemDel to comma
      if (a is pHead and b is pTop) or (a is pTop and b is pHead) then next repeat
      UProc.L tM, a, b
   end repeat
   if pHead <= tM["count"] and pTop <= tM["count"] then
      put (tM["vx"][pHead] + tM["vx"][pTop]) / 2 into tHx
      put (tM["vy"][pHead] + tM["vy"][pTop]) / 2 into tHy
      put (tM["vz"][pHead] + tM["vz"][pTop]) / 2 into tHz
      put sqrt((tM["vx"][pHead] - tM["vx"][pTop]) ^ 2 + (tM["vy"][pHead] - tM["vy"][pTop]) ^ 2 + (tM["vz"][pHead] - tM["vz"][pTop]) ^ 2) / 2 into tR
      UProc.Ball tM, tHx, tHy, tHz, tR
   end if
   return tM
end Person.Mesh

-- one cycle of a motion as pCount meshes: tF[1..pCount], tF["frames"], tF["fps"]
-- (a walk cycle lasts 1.1 s, a run 0.7 s, a wave 1.2 s, breathing 3 s)
function Person.Frames pMotion, pH, pCount
   local tF, i, tSecs
   if pCount is not a number or pCount < 1 then put 12 into pCount
   switch pMotion
      case "walk"
         put 1.1 into tSecs
         break
      case "run"
         put 0.7 into tSecs
         break
      case "wave"
         put 1.2 into tSecs
         break
      default
         put 3 into tSecs
   end switch
   repeat with i = 1 to pCount
      put Person.Mesh(Person.Pose(pMotion, (i - 1) / pCount, pH), kPersonEdges, 6, 7) into tF[i]
   end repeat
   put pCount into tF["frames"]
   put pCount / tSecs into tF["fps"]
   return tF
end Person.Frames

-- how far a motion carries the figure in one cycle, so the feet do not skate (pH tall):
-- a walk's two steps are about 0.72 of the height, a run's 1.2; stand and wave go nowhere
function Person.Stride pMotion, pH
   switch pMotion
      case "walk"
         return 0.72 * pH
      case "run"
         return 1.2 * pH
      default
         return 0
   end switch
end Person.Stride

-- a LIB_MOCAP stick clip (the text of library/<name>/<name>_stick.txt) as meshes pH tall:
-- tF[1..frames], tF["frames"], tF["fps"], tF["travel"] (forward per second, already
-- scaled to pH). Walks and runs keep only their loop cycle; others up to pMax frames
-- (empty = all), keeping every pEvery-th frame (empty = 1; fps drops to match). The clip's own joints and lines are used; the head ball sits between
-- Head and HeadTop_End when the clip has them. Turned to face -z like the math figure.
function Person.FromClip pText, pH, pMax, pEvery
   local tF, tLine, tNames, tEdges, tEdges1, tE, tHead, tTop, tJoints, tFrom, tTo, tFrame, tKept, tScale, tV, i, tPose, tTravel
   if pH is not a number or pH <= 0 then put 16 into pH
   put 30 into tF["fps"]
   put 0 into tTravel
   put 1 into tFrom
   put 999999 into tTo
   if pEvery is not an integer or pEvery < 1 then put 1 into pEvery
   put 0 into tFrame
   put 0 into tKept
   set the itemDel to comma
   repeat for each line tLine in pText
      if tLine is empty or char 1 of tLine is "#" then next repeat
      switch item 1 of tLine
         case "fps"
            put item 2 of tLine into tF["fps"]
            break
         case "travel"
            put item 2 of tLine into tTravel
            break
         case "cycle_travel"
            put item 2 of tLine into tTravel
            break
         case "cycle"
            put item 2 of tLine into tFrom
            put item 3 of tLine into tTo
            break
         case "joints"
            put item 2 of tLine into tJoints
            break
         case "names"
            put item 2 to -1 of tLine into tNames
            break
         case "edges"
            put item 2 of tLine into tEdges
            break
         default
            if char 1 of tLine is "-" or char 1 of tLine is a number then
               add 1 to tFrame
               if tFrame < tFrom or tFrame > tTo then next repeat
               if (tFrame - tFrom) mod pEvery is not 0 then next repeat
               add 1 to tKept
               if tKept > pMax and pMax is a number and pMax > 0 then next repeat
               put tLine into tV
               split tV by comma
               if tJoints is not a number then put the number of items of tLine div 3 into tJoints
               if tScale is empty then
                  -- the clip's height: its highest joint in the first frame kept
                  put 0 into tScale
                  repeat with i = 1 to tJoints
                     put max(tScale, tV[3 * i - 1]) into tScale
                  end repeat
                  if tScale <= 0 then put 1.75 into tScale
                  put pH / tScale into tScale
               end if
               put empty into tPose
               repeat with i = 1 to tJoints
                  put UPerson.R(-tV[3 * i - 2] * tScale) & comma & UPerson.R(-tV[3 * i - 1] * tScale) & comma & UPerson.R(-tV[3 * i] * tScale) & return after tPose
               end repeat
               delete the last char of tPose
               if tEdges1 is empty then
                  -- 0-based "a-b" to 1-based; the head joints by name
                  repeat for each word tE in tEdges
                     set the itemDel to "-"
                     put (item 1 of tE + 1) & "-" & (item 2 of tE + 1) & space after tEdges1
                  end repeat
                  set the itemDel to comma
                  set the wholeMatches to true
                  put itemOffset("Head", tNames) into tHead
                  put itemOffset("HeadTop_End", tNames) into tTop
               end if
               put Person.Mesh(tPose, word 1 to -1 of tEdges1, tHead, tTop) into tF[tKept]
            end if
      end switch
      set the itemDel to comma
   end repeat
   if pMax is a number and pMax > 0 then put min(tKept, pMax) into tKept
   put tKept into tF["frames"]
   if tF["fps"] is not a number then put 30 into tF["fps"]
   put tF["fps"] / pEvery into tF["fps"]
   if tTravel is not a number then put 0 into tTravel
   put tTravel * tScale into tF["travel"]
   return tF
end Person.FromClip
