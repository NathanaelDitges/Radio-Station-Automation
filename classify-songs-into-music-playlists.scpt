(*
    Reviews selected audio files or files inside a selected Finder folder.

    Opens each track in Sound Studio, plays short preview points,
    and lets the user manually classify the song by type.
    Based on the chosen category, the file is added to a matching
    playlist in the Music app.
*)

use AppleScript version "2.4" -- Requires Yosemite (10.10) or later
use scripting additions

on run
	
	tell application "Finder"
		
		-- Get whatever items are currently selected in Finder.
		set TheSelectedItems to selection
		
		-- Process each selected item one at a time.
		repeat with anItem in TheSelectedItems
			
			-- Determine whether the selected item is a file or a folder.
			set anItem_Type to class of anItem
			
			---------------- For Folders ----------------------------------
			-- If the selected item is a folder, process the files inside it.
			if anItem_Type is folder then
				
				-- Safety guard:
				-- If this folder contains subfolders, stop here so the script
				-- does not accidentally run through a large folder tree.
				if folders in anItem is not {} then
					display notification "Error: Please Select a folder closer to end of Folder Tree"
					exit repeat
				end if
				
				---------------- For Files in Selected Folder ------------------------------------
				-- Get every file directly inside the selected folder.
				set theInnerFiles to every file in anItem
				
				-- Open each file in Sound Studio for review/categorization.
				repeat with aInnerFile in theInnerFiles
					my openSoundStudio(aInnerFile)
				end repeat
				
			end if
			
			---------------- For Files ------------------------------------
			-- If the selected item is a single file, process it directly.
			if anItem_Type is document file then
				my openSoundStudio(anItem)
			end if
			
		end repeat
		
	end tell
	
end run


on openSoundStudio(filename)
	
	tell application "Sound Studio"
		
		-- Convert the incoming file reference into an alias that Sound Studio can open.
		set filename to (filename as alias)
		
		-- Open the audio file in Sound Studio.
		set d to open filename
		
		-- Read the total track length so preview playback can jump
		-- to multiple points in the song.
		set trackLength to total time of d
		
		-- Play short previews from several positions in the track:
		-- 25%, 50%, and 75% of the way through.
		play d from (trackLength / 4)
		delay 1
		play d from (trackLength / 2)
		delay 1.5
		play d from ((trackLength / 4) * 3)
		
		-- First classification dialog:
		-- Is the song instrumental, vocal, or should it be skipped?
		set theResult to display dialog "What is type of song is this?" buttons {"Instrumental", "Vocal", "Skip Track"}
		
		if button returned of theResult is "Instrumental" then
			
			-- Instrumental songs go into the Professional Recording playlist.
			my MakeITunesPlaylist(filename, "Professional Recording")
			
		else if button returned of theResult is "Vocal" then
			
			-- Second classification dialog for vocal tracks.
			set the2ndResult to display dialog "What is type of song is this?" buttons {"Choir", "Solo", "Cameroonian/A Cappella/Skip"}
			
			if button returned of the2ndResult is "Choir" then
				
				-- Third classification dialog for choir tracks.
				set the3rdResult to display dialog "What is type of song is this?" buttons {"Mens", "Ladies/Skip", "Mixed"}
				
				if button returned of the3rdResult is "Mens" then
					
					-- Men's choir track.
					my MakeITunesPlaylist(filename, "Mens Choir")
					
				else if button returned of the3rdResult is "Ladies/Skip" then
					
					-- Additional confirmation for ladies choir vs skip.
					set the4thResult to display dialog "What is type of song is this?" buttons {"Yes, Ladies Choir", "Skip Track"}
					
					if button returned of the4thResult is "Yes, Ladies Choir" then
						
						-- Ladies choir track.
						my MakeITunesPlaylist(filename, "Ladies Choir")
						
					else if button returned of the4thResult is "Skip Track" then
						
						-- Mark skipped/unusable tracks.
						my MakeITunesPlaylist(filename, "Unusable Songs")
						
					end if
					
				else if button returned of the3rdResult is "Mixed" then
					
					-- Mixed choir track.
					my MakeITunesPlaylist(filename, "Mixed Choir")
					
				end if
				
			else if button returned of the2ndResult is "Solo" then
				
				-- Third classification dialog for solo tracks.
				set the3rdResult to display dialog "What is type of song is this?" buttons {"Man", "Lady", "Skip Track"}
				
				if button returned of the3rdResult is "Man" then
					
					-- Male solo track.
					my MakeITunesPlaylist(filename, "Man Solo")
					
				else if button returned of the3rdResult is "Lady" then
					
					-- Female solo track.
					my MakeITunesPlaylist(filename, "Lady Solo")
					
				else if button returned of the3rdResult is "Skip Track" then
					
					-- Mark skipped/unusable tracks.
					my MakeITunesPlaylist(filename, "Unusable Songs")
					
				end if
				
			else if button returned of the2ndResult is "Cameroonian/A Cappella/Skip" then
				
				-- Third classification dialog for special vocal categories.
				set the3rdResult to display dialog "What is type of song is this?" buttons {"Cameroonian", "A Cappella", "Skip Track"}
				
				if button returned of the3rdResult is "Cameroonian" then
					
					-- Cameroonian congregational track.
					my MakeITunesPlaylist(filename, "Cameroon Congregation")
					
				else if button returned of the3rdResult is "A Cappella" then
					
					-- A cappella track.
					my MakeITunesPlaylist(filename, "A Cappella")
					
				else if button returned of the3rdResult is "Skip Track" then
					
					-- Mark skipped/unusable tracks.
					my MakeITunesPlaylist(filename, "Unusable Songs")
					
				end if
				
			end if
			
		else if button returned of theResult is "Skip Track" then
			
			-- Directly skip the track and place it in the unusable playlist.
			my MakeITunesPlaylist(filename, "Unusable Songs")
			
		end if
		
		-- Close the file in Sound Studio after categorization is complete.
		close d
		
	end tell
	
end openSoundStudio


on MakeITunesPlaylist(filename, PLaylistname)
	
	tell application "Music"
		
		-- Add the selected file to the specified Music playlist.
		add filename to playlist PLaylistname
		
	end tell
	
end MakeITunesPlaylist
