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
   return "Proc.House"
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
