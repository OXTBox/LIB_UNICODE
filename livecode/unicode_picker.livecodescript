script "unicode_picker"
######################################################################################
## UnicodePicker  (LIB_UNICODE, Opus 19 Nov 2026) -- the stack script of the picker palette
## A small floating palette of the registry's characters (REGISTRY.tsv through lib_unicode).
##   Entities   drag one into a game window and let go: its procedure builds the thing there,
##              standing on the ground (y = 0) under the mouse. A click drops it in the middle
##              of the front game window. Dim = planned, no procedure written yet.
##   Tools, Marks   a click copies the character to the clipboard (for button labels).
##   S M L      the size it is built at (its width: 20, 40, 80).
##   Take back  removes the last thing dropped.
##   Moves      what a dropped person (웃) does: stands, walks or runs in a ring round the
##              spot, waves, or dances (a LIB_MOCAP clip, when the library has it). People
##              move on their own; a paused game (Escape) holds them still.
## Game windows = the Game Player's "Play <Game>" stacks (HOWTO's Run, GAME_Browser, GL.Open)
## in this same program; people need the Game Player's engine (Entity.SetMesh). Engine 1 (Vibecode3D, XT) only: an xt3d window draws with raylib's
## own camera, so a drop there would land in the wrong spot (later).
## The stack holds no characters: Picker.Build makes the controls, Picker.Fill the grid.
######################################################################################

constant kFallbackFolder = "//wsl$/Ubuntu/home/igame3d/projects/LIB_UNICODE/livecode"
constant kLayout = 3
constant kCols = 6
constant kCell = 40
constant kGap = 4
constant kPad = 8
constant kGhost = "UnicodePickerGhost"
constant kSymbolFont = "Segoe UI Symbol"
-- colours (dark mode, as the HOWTO stack)
constant kPaper = "14,17,22"
constant kPanel = "24,29,37"
constant kInk = "216,222,233"
constant kDim = "90,98,110"
constant kAccent = "124,200,255"
constant kButton = "40,52,68"
constant kOn = "60,110,160"

local sKind        -- the tab shown: entity, tool, mark
local sSize        -- the width things are built at
local sDropped     -- what was dropped, one "stack<tab>id" a line, newest last
local sMoves       -- what a dropped person does: stand, walk, run, wave, dance
local sPeople      -- sPeople[id]: stack, mesh (prefix), frames, fps, x, z, ring, speed, t
local sAnimMsg     -- the pending Picker.Animate message
local sAnimLast    -- the milliseconds at the last Picker.Animate
local sPersonInfo  -- sPersonInfo[prefix] = frames & tab & fps & tab & stride of meshes made

constant kAnimMS = 66
constant kDanceClip = "FreeBVH_DANCE"

-------------------------------------------------------------------- open / close

on preOpenStack
   Picker.UseLib
   if the cLayout of me is not kLayout then Picker.Build
   set the scaleFactor of me to 1
   set the topLeft of me to 200, 32
   if sKind is empty then put "entity" into sKind
   if sSize is not a number then put 40 into sSize
   if sMoves is empty then put "walk" into sMoves
   Picker.Fill sKind
   Picker.ShowSize
   Picker.Status "Drag a character into a game window."
end preOpenStack

on openStack
   if not the visible of me then show me
   pass openStack
end openStack

-- LIB_ALPHA 12b: closing frees the stack (and its ghost window)
on closeStackRequest
   Picker.StopAnimate
   Picker.KillGhost
   set the destroyStack of me to true
   pass closeStackRequest
end closeStackRequest

on closeStack
   Picker.StopAnimate
   Picker.KillGhost
   pass closeStack
end closeStack

-- lib_unicode, from the folder this stack is in
command Picker.UseLib
   local tPath
   if "lib_unicode" is among the lines of the stacksInUse then exit Picker.UseLib
   put Picker.Folder() & "/lib_unicode.livecodescript" into tPath
   if there is not a file tPath then put kFallbackFolder & "/lib_unicode.livecodescript" into tPath
   start using stack tPath
end Picker.UseLib

function Picker.Folder
   local tPath
   put the effective filename of me into tPath
   if tPath is empty then return kFallbackFolder
   set the itemDel to "/"
   return item 1 to -2 of tPath
end Picker.Folder

-------------------------------------------------------------------- clicks

on mouseEnter
   local tChar
   put the cChar of the target into tChar
   if tChar is not empty then Picker.ShowInfo tChar
end mouseEnter

on mouseDown pButton
   local tChar
   if pButton is not 1 then pass mouseDown
   put the cChar of the target into tChar
   if tChar is empty then pass mouseDown
   if sKind is "entity" then
      if the cReady of the target then
         Picker.Drag tChar
      else
         Picker.Status Unicode.Meaning(tChar) & ": planned, no procedure written yet."
      end if
   end if
end mouseDown

on mouseUp pButton
   local tChar
   if pButton is not 1 then pass mouseUp
   put the cChar of the target into tChar
   if tChar is not empty then
      if sKind is not "entity" then
         set the clipboardData["text"] to tChar
         Picker.Status "Copied" && tChar && "(" & Unicode.Meaning(tChar) & ")."
      end if
      exit mouseUp
   end if
   switch the short name of the target
      case "TabEntity"
         Picker.Fill "entity"
         break
      case "TabTool"
         Picker.Fill "tool"
         break
      case "TabMark"
         Picker.Fill "mark"
         break
      case "SizeS"
         put 20 into sSize
         Picker.ShowSize
         break
      case "SizeM"
         put 40 into sSize
         Picker.ShowSize
         break
      case "SizeL"
         put 80 into sSize
         Picker.ShowSize
         break
      case "TakeBack"
         Picker.TakeBack
         break
      case "Moves"
         Picker.NextMoves
         break
      default
         pass mouseUp
   end switch
end mouseUp

-------------------------------------------------------------------- drag and drop

-- follow the mouse with a ghost of the character until it is let go, then drop it in the
-- game window under the mouse. Barely moved = a click: the middle of the front game window.
command Picker.Drag pChar
   local tStart, tLoc, tMoved, tWin, tLast
   put the screenMouseLoc into tStart
   put false into tMoved
   repeat while the mouse is down
      put the screenMouseLoc into tLoc
      if not tMoved and abs(item 1 of tLoc - item 1 of tStart) + abs(item 2 of tLoc - item 2 of tStart) > 6 then
         put true into tMoved
         Picker.ShowGhost pChar
      end if
      if tMoved then
         Picker.MoveGhost tLoc
         put Picker.WindowAt(tLoc) into tWin
         if tWin is not tLast then
            put tWin into tLast
            if tWin is empty then Picker.Status "Let go over a game window."
            else Picker.Status "Let go: into" && Picker.WindowName(tWin) & "."
         end if
      end if
      wait 15 milliseconds with messages
   end repeat
   Picker.HideGhost
   put the screenMouseLoc into tLoc
   if tMoved then
      put Picker.WindowAt(tLoc) into tWin
      if tWin is empty then
         Picker.Status "Not over a game window: nothing dropped."
         exit Picker.Drag
      end if
      Picker.DropIn tWin, pChar, item 1 of tLoc - the left of stack tWin, item 2 of tLoc - the top of stack tWin
   else
      put line 1 of Picker.Windows() into tWin
      if tWin is empty then
         Picker.Status "No game window open (HOWTO's Run, or the GAME_Browser, opens one)."
         exit Picker.Drag
      end if
      Picker.DropIn tWin, pChar, the width of stack tWin / 2, the height of stack tWin / 2
   end if
end Picker.Drag

-- the open game windows, front first
function Picker.Windows
   local tS, tOut
   repeat for each line tS in the openStacks
      if tS begins with "Play " and the mode of stack tS is not 0 and the visible of stack tS then
         put tS & return after tOut
      end if
   end repeat
   delete the last char of tOut
   return tOut
end Picker.Windows

-- the game window under a point on the screen (empty = none)
function Picker.WindowAt pScreenLoc
   local tS
   repeat for each line tS in Picker.Windows()
      if pScreenLoc is within the rect of stack tS then return tS
   end repeat
   return empty
end Picker.WindowAt

function Picker.WindowName pStack
   if the uGame of stack pStack is not empty then return the uGame of stack pStack
   return pStack
end Picker.WindowName

-- build the character's thing and put it in pStack's scene under card point pX, pY
command Picker.DropIn pStack, pChar, pX, pY
   global gMeshCache
   local tWas, tMesh, tBuilt, tP, tId, tErr
   put the defaultStack into tWas
   if Unicode.Procedure(pChar) is "Proc.Person" then
      Picker.DropPerson pStack, pChar, pX, pY
      exit Picker.DropIn
   end if
   set the defaultStack to pStack
   try
      put "uni_" & char 3 to -1 of Unicode.Code(pChar) & "_" & sSize into tMesh
      if gMeshCache[tMesh]["count"] is empty then
         put Unicode.Build(pChar, sSize) into tBuilt
         if tBuilt is empty then
            set the defaultStack to tWas
            Picker.Status Unicode.LastError()
            exit Picker.DropIn
         end if
         Mesh.Define tMesh, tBuilt
      end if
      put Picker.GroundAt(pX, pY) into tP
      put Entity.Spawn(tMesh, item 1 of tP, item 2 of tP, item 3 of tP, Picker.Colour(Unicode.Meaning(pChar))) into tId
      put pStack & tab & tId & return after sDropped
      -- a paused or still game draws nothing by itself: draw this frame now
      dispatch "Player.Draw" to stack pStack
   catch tErr
      set the defaultStack to tWas
      Picker.Status "Could not drop it:" && line 1 of tErr
      exit Picker.DropIn
   end try
   set the defaultStack to tWas
   Picker.Status pChar && Unicode.Meaning(pChar) && "at" && round(item 1 of tP) & "," && round(item 3 of tP) && "in" && Picker.WindowName(pStack) & "."
end Picker.DropIn

-------------------------------------------------------------------- people (웃)

-- the meshes for a person doing sMoves at sSize, made once a window: "<prefix>.1" .. ".n".
-- Gives prefix & tab & frames & tab & fps & tab & stride (empty when it could not be made).
function Picker.PersonMeshes pMoves
   global gMeshCache
   local tPrefix, tF, i, tClip, tH
   put sSize * 0.4 into tH
   put "uni_person_" & pMoves & "_" & sSize into tPrefix
   if sPersonInfo[tPrefix] is not empty and gMeshCache[tPrefix & ".1"]["count"] is not empty then
      return tPrefix & tab & sPersonInfo[tPrefix]
   end if
   if pMoves is "dance" then
      put Picker.ClipFile(kDanceClip) into tClip
      if tClip is empty then return empty
      put Person.FromClip(url ("file:" & tClip), tH, 120, 2) into tF
   else
      put Person.Frames(pMoves, tH, 12) into tF
   end if
   if tF["frames"] < 1 then return empty
   repeat with i = 1 to tF["frames"]
      Mesh.Define tPrefix & "." & i, tF[i]
   end repeat
   put tF["frames"] & tab & tF["fps"] & tab & Person.Stride(pMoves, tH) into sPersonInfo[tPrefix]
   return tPrefix & tab & sPersonInfo[tPrefix]
end Picker.PersonMeshes

-- a LIB_MOCAP stick clip next to this LIB (empty when the library does not have it)
function Picker.ClipFile pName
   local tPath
   put Picker.Folder() into tPath
   set the itemDel to "/"
   put item 1 to -3 of tPath & "/LIB_MOCAP/library/" & pName & "/" & pName & "_stick.txt" into tPath
   if there is a file tPath then return tPath
   return empty
end Picker.ClipFile

command Picker.DropPerson pStack, pChar, pX, pY
   local tWas, tInfo, tP, tId, tErr, tRing, tPrefix, tFrames, tFPS, tStride
   put the defaultStack into tWas
   set the defaultStack to pStack
   try
      Picker.Status "Making the person's frames..."
      put Picker.PersonMeshes(sMoves) into tInfo
      if tInfo is empty then
         set the defaultStack to tWas
         Picker.Status "No" && kDanceClip && "clip in LIB_MOCAP/library: pick other moves."
         exit Picker.DropPerson
      end if
      set the itemDel to tab
      put item 1 of tInfo into tPrefix
      put item 2 of tInfo into tFrames
      put item 3 of tInfo into tFPS
      put item 4 of tInfo into tStride
      set the itemDel to comma
      put Picker.GroundAt(pX, pY) into tP
      put sSize * 0.4 * 1.5 into tRing
      put Entity.Spawn(tPrefix & ".1", item 1 of tP, item 2 of tP, item 3 of tP, Picker.Colour(Unicode.Meaning(pChar))) into tId
      put pStack into sPeople[tId]["stack"]
      put tPrefix into sPeople[tId]["mesh"]
      put tFrames into sPeople[tId]["frames"]
      put tFPS into sPeople[tId]["fps"]
      -- walkers go round a ring (centre = the spot) at the speed their feet carry them
      put 0 into sPeople[tId]["speed"]
      if tStride > 0 then put tStride * tFPS / tFrames into sPeople[tId]["speed"]
      put item 1 of tP into sPeople[tId]["x"]
      put item 3 of tP into sPeople[tId]["z"]
      put tRing into sPeople[tId]["ring"]
      put 0 into sPeople[tId]["t"]
      put pStack & tab & tId & return after sDropped
      Picker.PlacePerson tId
      dispatch "Player.Draw" to stack pStack
   catch tErr
      set the defaultStack to tWas
      Picker.Status "Could not drop the person:" && line 1 of tErr
      exit Picker.DropPerson
   end try
   set the defaultStack to tWas
   Picker.Status pChar && "a person (" & Picker.MovesWord(sMoves) & ") in" && Picker.WindowName(pStack) & "."
   Picker.StartAnimate
end Picker.DropPerson

-- frame, place and heading of person pId after its own time t (seconds); the default stack
-- must be its window. A walker's angle round the ring is distance / radius; it faces along
-- the ring (the figure faces -z, so heading (dx,dz) is the turn atan2(-dx, -dz)).
command Picker.PlacePerson pId
   local tN, tA, tX, tZ, tR
   put trunc(sPeople[pId]["t"] * sPeople[pId]["fps"]) mod sPeople[pId]["frames"] + 1 into tN
   Entity.SetMesh pId, sPeople[pId]["mesh"] & "." & tN
   if sPeople[pId]["speed"] > 0 then
      put sPeople[pId]["ring"] into tR
      put sPeople[pId]["speed"] * sPeople[pId]["t"] / tR into tA
      put sPeople[pId]["x"] + tR * cos(tA) into tX
      put sPeople[pId]["z"] + tR * sin(tA) into tZ
      Entity.SetPosition pId, tX, 0, tZ
      -- going round: the way ahead is (-sin a, cos a)
      Entity.SetRotation pId, 0, atan2(sin(tA), -cos(tA)), 0
   end if
end Picker.PlacePerson

command Picker.StartAnimate
   if sAnimMsg is not empty then exit Picker.StartAnimate
   put the milliseconds into sAnimLast
   send "Picker.Animate" to me in kAnimMS milliseconds
   put the result into sAnimMsg
end Picker.StartAnimate

command Picker.StopAnimate
   if sAnimMsg is not empty then cancel sAnimMsg
   put empty into sAnimMsg
end Picker.StopAnimate

-- every person a step on; a window whose own game loop is not drawing (stopped, still) is
-- drawn from here. A paused game holds its people still. Stops when nobody is left.
on Picker.Animate
   global bPaused, bStill
   local tId, tStack, tDT, tWas, tErr, tDraw, tS, tLeft
   put empty into sAnimMsg
   put (the milliseconds - sAnimLast) / 1000 into tDT
   put the milliseconds into sAnimLast
   if bPaused is true then
      Picker.StartAnimate
      exit Picker.Animate
   end if
   put the defaultStack into tWas
   put 0 into tLeft
   repeat for each key tId in sPeople
      put sPeople[tId]["stack"] into tStack
      if there is not a stack tStack or the mode of stack tStack is 0 then
         delete variable sPeople[tId]
         next repeat
      end if
      set the defaultStack to tStack
      try
         if not Entity.Exists(tId) then
            delete variable sPeople[tId]
            next repeat
         end if
         add min(tDT, 0.25) to sPeople[tId]["t"]
         Picker.PlacePerson tId
         add 1 to tLeft
         if tStack is not among the lines of tDraw then put tStack & return after tDraw
      catch tErr
         delete variable sPeople[tId]
      end try
   end repeat
   if tWas is not empty and there is a stack tWas then set the defaultStack to tWas
   repeat for each line tS in tDraw
      if not Picker.GameDraws(tS) then dispatch "Player.Draw" to stack tS
   end repeat
   if tLeft > 0 then Picker.StartAnimate
end Picker.Animate

-- true when a window's own game loop draws it (a tick is waiting and the game is not still)
function Picker.GameDraws pStack
   global bStill
   if bStill is true then return false
   return the pendingMessages contains ("Player.Tick," & the long id of stack pStack)
end Picker.GameDraws

command Picker.NextMoves
   local tAll, n
   put "stand,walk,run,wave" into tAll
   if Picker.ClipFile(kDanceClip) is not empty then put ",dance" after tAll
   put itemOffset(sMoves, tAll) into n
   put item (n mod the number of items of tAll) + 1 of tAll into sMoves
   Picker.ShowMoves
   Picker.Status "A dropped person" && Picker.MovesWord(sMoves) & "."
end Picker.NextMoves

command Picker.ShowMoves
   if there is a button "Moves" of card 1 of me then set the label of button "Moves" of card 1 of me to Picker.MovesWord(sMoves)
end Picker.ShowMoves

function Picker.MovesWord pMoves
   switch pMoves
      case "stand"
         return "stands"
      case "walk"
         return "walks round"
      case "run"
         return "runs round"
      case "wave"
         return "waves"
      case "dance"
         return "dances"
   end switch
   return pMoves
end Picker.MovesWord

-- remove the last thing dropped (when its window is still open)
command Picker.TakeBack
   local tLine, tWas
   set the itemDel to tab
   repeat while sDropped is not empty
      put the last line of sDropped into tLine
      delete the last line of sDropped
      if there is a stack (item 1 of tLine) and the mode of stack (item 1 of tLine) is not 0 then
         put the defaultStack into tWas
         set the defaultStack to item 1 of tLine
         delete variable sPeople[item 2 of tLine]
         Entity.Kill item 2 of tLine
         dispatch "Player.Draw" to stack (item 1 of tLine)
         set the defaultStack to tWas
         Picker.Status "Took back" && item 2 of tLine & "."
         exit Picker.TakeBack
      end if
   end repeat
   Picker.Status "Nothing to take back."
end Picker.TakeBack

-- the world point (x,y,z) under card point pX, pY of the game being drawn: where the mouse's
-- ray meets the ground (y = 0). When the ground is not under it (the camera looks level, or
-- the ground is very far), the point on that ray as deep as the world's centre is.
-- Engine 1 math: an object at world p shows at camera point Rcam * (p + PIV - Rscene*PIV + CAM)
-- (Render.FrameMatrices / Xform.Object), so p = transpose(Rcam) * camera point - that offset.
function Picker.GroundAt pX, pY
   global CenterX, CenterY, gFocalLength
   local tRay, dx, dy, dz, R, Rs, tRP, oX, oY, oZ, wx, wy, wz, tDepth, tT, tFar
   put ScreenToCameraRay(pX, pY, CenterX, CenterY, Engine.Get("MOVEX"), Engine.Get("MOVEY"), Engine.Get("theSCALE"), gFocalLength) into tRay
   if tRay is empty then return "0,0,0"
   put word 1 of tRay into dx
   put word 2 of tRay into dy
   put word 3 of tRay into dz
   put Mat3.Camera() into R
   put Mat3.RotZYX(Engine.Get("ANGLEX"), Engine.Get("ANGLEY"), Engine.Get("ANGLEZ")) into Rs
   put Mat3.Apply(Rs, Engine.Get("PIVX"), Engine.Get("PIVY"), Engine.Get("PIVZ")) into tRP
   put Engine.Get("PIVX") - word 1 of tRP + Engine.Get("CAMX") into oX
   put Engine.Get("PIVY") - word 2 of tRP + Engine.Get("CAMY") into oY
   put Engine.Get("PIVZ") - word 3 of tRP + Engine.Get("CAMZ") into oZ
   set the itemDel to comma
   -- the ray's direction in the world (transpose of the camera's turn)
   put (item 1 of R) * dx + (item 4 of R) * dy + (item 7 of R) * dz into wx
   put (item 2 of R) * dx + (item 5 of R) * dy + (item 8 of R) * dz into wy
   put (item 3 of R) * dx + (item 6 of R) * dy + (item 9 of R) * dz into wz
   -- how deep the world's centre is in front of the camera
   put word 3 of Mat3.Apply(R, oX, oY, oZ) into tDepth
   if tDepth is not a number or tDepth < 50 then put 600 into tDepth
   put tDepth / max(dz, 0.05) into tFar
   put tFar into tT
   if abs(wy) > 0.0001 then
      if oY / wy > 1 and oY / wy < tFar * 6 then put oY / wy into tT
   end if
   return (tT * wx - oX) & comma & (tT * wy - oY) & comma & (tT * wz - oZ)
end Picker.GroundAt

-- the colour a thing is drawn in, by its meaning
function Picker.Colour pMeaning
   switch pMeaning
      case "house"
         return "#E0A868"
      case "car"
         return "#FF5A5A"
      case "truck"
         return "#FFA040"
      case "cloud"
         return "#E8F0FF"
      case "storm cloud"
         return "#8FA0D8"
      case "person"
         return "#FFE070"
   end switch
   return "#7CFF7C"
end Picker.Colour

-------------------------------------------------------------------- the ghost window

command Picker.ShowGhost pChar
   local tWas
   if there is not a stack kGhost then
      put the defaultStack into tWas
      lock messages
      create invisible stack kGhost
      set the destroyStack of stack kGhost to true
      set the style of stack kGhost to "palette"
      set the decorations of stack kGhost to empty
      set the backgroundColor of stack kGhost to kPanel
      set the rect of stack kGhost to 0, 0, kCell + 8, kCell + 8
      set the defaultStack to kGhost
      Picker.Template "field"
      create field "Char"
      set the rect of field "Char" to 0, 0, kCell + 8, kCell + 8
      set the textFont of field "Char" to kSymbolFont
      set the textSize of field "Char" to 28
      set the textAlign of field "Char" to "center"
      set the lockText of field "Char" to true
      set the traversalOn of field "Char" to false
      set the defaultStack to tWas
      unlock messages
   end if
   set the text of field "Char" of stack kGhost to pChar
   set the foregroundColor of field "Char" of stack kGhost to kAccent
   Picker.MoveGhost the screenMouseLoc
   show stack kGhost
end Picker.ShowGhost

command Picker.MoveGhost pLoc
   if there is a stack kGhost then set the topLeft of stack kGhost to item 1 of pLoc + 14, item 2 of pLoc + 14
end Picker.MoveGhost

command Picker.HideGhost
   if there is a stack kGhost then hide stack kGhost
end Picker.HideGhost

command Picker.KillGhost
   if there is a stack kGhost then
      lock messages
      delete stack kGhost
      unlock messages
   end if
end Picker.KillGhost

-------------------------------------------------------------------- building the palette

-- the template's colours before every create (owner's rule)
command Picker.Template pType
   switch pType
      case "button"
         reset the templateButton
         set the textColor of the templateButton to kInk
         set the foregroundColor of the templateButton to kInk
         set the backgroundColor of the templateButton to kButton
         set the borderColor of the templateButton to kPanel
         set the hiliteColor of the templateButton to kOn
         break
      case "field"
         reset the templateField
         set the textColor of the templateField to kInk
         set the foregroundColor of the templateField to kInk
         set the backgroundColor of the templateField to kPanel
         set the borderColor of the templateField to kPanel
         break
   end switch
end Picker.Template

command Picker.Button pName, pLabel, pL, pT, pR, pB
   Picker.Template "button"
   create button pName in card 1 of me
   set the style of button pName of card 1 of me to "rectangle"
   set the label of button pName of card 1 of me to pLabel
   set the showName of button pName of card 1 of me to true
   set the opaque of button pName of card 1 of me to true
   set the threeD of button pName of card 1 of me to false
   set the showFocusBorder of button pName of card 1 of me to false
   set the traversalOn of button pName of card 1 of me to false
   set the autoHilite of button pName of card 1 of me to false
   set the rect of button pName of card 1 of me to pL, pT, pR, pB
end Picker.Button

command Picker.Field pName, pL, pT, pR, pB
   Picker.Template "field"
   create field pName in card 1 of me
   set the rect of field pName of card 1 of me to pL, pT, pR, pB
   set the lockText of field pName of card 1 of me to true
   set the traversalOn of field pName of card 1 of me to false
   set the threeD of field pName of card 1 of me to false
   set the showBorder of field pName of card 1 of me to false
   set the dontWrap of field pName of card 1 of me to false
end Picker.Field

-- every control again (the grid is made by Picker.Fill)
command Picker.Build
   local tW, tTabW, x
   lock screen
   lock messages
   repeat while the number of controls of card 1 of me > 0
      delete control 1 of card 1 of me
   end repeat
   put kPad * 2 + kCols * kCell + (kCols - 1) * kGap into tW
   set the width of me to tW
   set the backgroundColor of me to kPaper
   set the resizable of me to false
   put (tW - kPad * 2 - kGap * 2) div 3 into tTabW
   put kPad into x
   Picker.Button "TabEntity", "Entities", x, kPad, x + tTabW, kPad + 22
   add tTabW + kGap to x
   Picker.Button "TabTool", "Tools", x, kPad, x + tTabW, kPad + 22
   add tTabW + kGap to x
   Picker.Button "TabMark", "Marks", x, kPad, x + tTabW, kPad + 22
   Picker.Field "Info", kPad, 0, tW - kPad, 54
   set the textSize of field "Info" of card 1 of me to 11
   Picker.Field "SizeLabel", kPad, 0, kPad + 40, 22
   set the backgroundColor of field "SizeLabel" of card 1 of me to kPaper
   set the textColor of field "SizeLabel" of card 1 of me to kDim
   set the text of field "SizeLabel" of card 1 of me to "Size"
   Picker.Button "SizeS", "S", 0, 0, 30, 22
   Picker.Button "SizeM", "M", 0, 0, 30, 22
   Picker.Button "SizeL", "L", 0, 0, 30, 22
   Picker.Button "TakeBack", "Take back", 0, 0, 84, 22
   Picker.Field "MovesLabel", kPad, 0, kPad + 64, 22
   set the backgroundColor of field "MovesLabel" of card 1 of me to kPaper
   set the textColor of field "MovesLabel" of card 1 of me to kDim
   set the text of field "MovesLabel" of card 1 of me to "웃 moves"
   Picker.Button "Moves", "walks", 0, 0, 100, 22
   set the tooltip of button "Moves" of card 1 of me to "What a dropped person does (click for the next)"
   Picker.Field "Status", kPad, 0, tW - kPad, 34
   set the backgroundColor of field "Status" of card 1 of me to kPaper
   set the textColor of field "Status" of card 1 of me to kDim
   set the textSize of field "Status" of card 1 of me to 11
   set the cLayout of me to kLayout
   unlock messages
   unlock screen
end Picker.Build

-- the grid for one kind (entity, tool, mark), and everything below it moved under it
command Picker.Fill pKind
   local tChars, tChar, n, tRow, tCol, x, y, tName, tTop, tRows, tW
   put pKind into sKind
   lock screen
   lock messages
   repeat with n = the number of buttons of card 1 of me down to 1
      if the short name of button n of card 1 of me begins with "C_" then delete button n of card 1 of me
   end repeat
   put Unicode.List(pKind) into tChars
   put kPad + 22 + kGap * 2 into tTop
   put 0 into n
   repeat for each line tChar in tChars
      add 1 to n
      put (n - 1) mod kCols into tCol
      put (n - 1) div kCols into tRow
      put kPad + tCol * (kCell + kGap) into x
      put tTop + tRow * (kCell + kGap) into y
      put "C_" & n into tName
      Picker.Button tName, tChar, x, y, x + kCell, y + kCell
      set the textFont of button tName of card 1 of me to kSymbolFont
      set the textSize of button tName of card 1 of me to 22
      set the cChar of button tName of card 1 of me to tChar
      set the tooltip of button tName of card 1 of me to Unicode.Meaning(tChar)
      if pKind is "entity" then
         set the cReady of button tName of card 1 of me to (Unicode.Procedure(tChar) is among the lines of Unicode.Written())
         if not the cReady of button tName of card 1 of me then
            set the textColor of button tName of card 1 of me to kDim
            set the backgroundColor of button tName of card 1 of me to kPanel
         end if
      end if
   end repeat
   put max(1, (n + kCols - 1) div kCols) into tRows
   put tTop + tRows * (kCell + kGap) + kGap into y
   put the width of me into tW
   set the topLeft of field "Info" of card 1 of me to kPad, y
   add 54 + kGap to y
   set the topLeft of field "SizeLabel" of card 1 of me to kPad, y
   set the topLeft of button "SizeS" of card 1 of me to kPad + 40, y
   set the topLeft of button "SizeM" of card 1 of me to kPad + 40 + 34, y
   set the topLeft of button "SizeL" of card 1 of me to kPad + 40 + 68, y
   set the topRight of button "TakeBack" of card 1 of me to tW - kPad, y
   add 22 + kGap to y
   if pKind is "entity" then
      set the topLeft of field "MovesLabel" of card 1 of me to kPad, y
      set the topLeft of button "Moves" of card 1 of me to kPad + 68, y
      Picker.ShowMoves
      add 22 + kGap to y
   end if
   set the topLeft of field "Status" of card 1 of me to kPad, y
   set the height of me to y + 34 + kPad
   repeat for each item tName in "TabEntity,TabTool,TabMark"
      set the backgroundColor of button tName of card 1 of me to kButton
   end repeat
   switch pKind
      case "entity"
         set the backgroundColor of button "TabEntity" of card 1 of me to kOn
         set the visible of button "TakeBack" of card 1 of me to true
         break
      case "tool"
         set the backgroundColor of button "TabTool" of card 1 of me to kOn
         set the visible of button "TakeBack" of card 1 of me to false
         break
      case "mark"
         set the backgroundColor of button "TabMark" of card 1 of me to kOn
         set the visible of button "TakeBack" of card 1 of me to false
         break
   end switch
   repeat for each item tName in "SizeLabel,SizeS,SizeM,SizeL,MovesLabel,Moves"
      set the visible of control tName of card 1 of me to (pKind is "entity")
   end repeat
   set the text of field "Info" of card 1 of me to empty
   unlock messages
   unlock screen
   if pKind is "entity" then Picker.Status "Drag a character into a game window. Dim ones are planned."
   else Picker.Status "Click a character to copy it."
end Picker.Fill

command Picker.ShowSize
   repeat for each item tName in "SizeS,SizeM,SizeL"
      set the backgroundColor of button tName of card 1 of me to kButton
   end repeat
   switch sSize
      case 20
         set the backgroundColor of button "SizeS" of card 1 of me to kOn
         break
      case 80
         set the backgroundColor of button "SizeL" of card 1 of me to kOn
         break
      default
         set the backgroundColor of button "SizeM" of card 1 of me to kOn
   end switch
end Picker.ShowSize

command Picker.ShowInfo pChar
   local tText, tProc
   put pChar && Unicode.Meaning(pChar) && " " & Unicode.Code(pChar) & return into tText
   put toLower(Unicode.Field(pChar, "name")) & return after tText
   put Unicode.Procedure(pChar) into tProc
   if tProc is not empty then
      if tProc is among the lines of Unicode.Written() then put "builds with" && tProc after tText
      else put tProc && "planned" after tText
   else
      put "used in:" && Unicode.Field(pChar, "used_in") after tText
   end if
   set the text of field "Info" of card 1 of me to tText
   set the textColor of line 1 of field "Info" of card 1 of me to kAccent
end Picker.ShowInfo

command Picker.Status pText
   if there is a field "Status" of card 1 of me then set the text of field "Status" of card 1 of me to pText
end Picker.Status
