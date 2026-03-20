(*
    Converts selected WAV files using the Music app's built-in converter.

    Walks through selected folders and nested subfolders, converts WAV files,
    moves the converted tracks back into their original folders, deletes the
    original WAV files, and places the converted tracks into Music playlists
    based on the surrounding folder names.

    Warning: This was designed for a specific workflow....
      -  Empties trash automatically
*)

use AppleScript version "2.4"
use scripting additions

on run
	tell application "Finder"
		set selectedItems to selection as alias list
	end tell
	
	if (count of selectedItems) is 0 then
		display dialog "Select one or more files or folders in Finder first." buttons {"OK"} default button 1
		return
	end if
	
	set wavFilesToProcess to {}
	set convertedCount to 0
	set failedItems to {}
	
	-- Build one flat list of WAV files from the current Finder selection.
	repeat with anItem in selectedItems
		try
			tell application "Finder"
				set itemClass to class of anItem
			end tell
			
			if itemClass is folder then
				set wavFilesToProcess to wavFilesToProcess & my collectWavFilesFromFolder(anItem)
			else
				tell application "Finder"
					if name extension of anItem is "wav" then
						set end of wavFilesToProcess to (anItem as alias)
					end if
				end tell
			end if
		on error errMsg
			set end of failedItems to ("Selection error: " & errMsg)
		end try
	end repeat
	
	if (count of wavFilesToProcess) is 0 then
		display dialog "No WAV files were found in the current selection." buttons {"OK"} default button 1
		return
	end if
	
	-- Process each WAV file.
	repeat with aWavFile in wavFilesToProcess
		set filePathText to ""
		
		try
			set filePathText to POSIX path of (aWavFile as alias)
			
			-- Convert the WAV through Music, move the converted file back
			-- to the original folder, delete the WAV, and return the new track.
			set convertedTrack to my convertAudioFileInMusic(aWavFile)
			
			-- Add the converted track to a playlist based on its folder names.
			my addTrackToDerivedPlaylist(convertedTrack)
			
			set convertedCount to convertedCount + 1
			
		on error errMsg
			if filePathText is "" then
				set end of failedItems to ("Unknown file — " & errMsg)
			else
				set end of failedItems to (filePathText & " — " & errMsg)
			end if
		end try
	end repeat
	
	-- Final report.
	set reportMessage to "Finished." & return & return & "Converted: " & convertedCount
	
	if (count of failedItems) > 0 then
		set reportMessage to reportMessage & return & return & "Failed:" & return & my joinList(failedItems, return)
	end if
	
	display dialog reportMessage buttons {"OK"} default button 1
end run


on collectWavFilesFromFolder(rootFolder)
	-- Recursively collect all WAV files inside a Finder folder.
	set foundFiles to {}
	
	tell application "Finder"
		-- Get WAV files directly inside this folder.
		try
			set directFiles to every file of rootFolder whose name extension is "wav"
			repeat with aFile in directFiles
				set end of foundFiles to (aFile as alias)
			end repeat
		end try
		
		-- Recurse into subfolders.
		try
			set subFolders to every folder of rootFolder
			repeat with aSubFolder in subFolders
				set foundFiles to foundFiles & my collectWavFilesFromFolder(aSubFolder)
			end repeat
		end try
	end tell
	
	return foundFiles
end collectWavFilesFromFolder


on convertAudioFileInMusic(fileToConvert)
	-- Import/open the WAV file so Music can access it.
	open fileToConvert
	
	-- Remember the original folder so the converted file can be moved back there.
	tell application "Finder"
		set originalFolder to (container of fileToConvert) as alias
	end tell
	
	tell application "Music"
		-- Briefly make sure the imported/opened file becomes the current track.
		pause
		delay 1
		play
		delay 1
		
		set sourceTrack to current track
		set sourceTrackLocation to location of sourceTrack
		
		-- Convert using Music's current import/conversion settings.
		set convertedTracks to convert sourceTrack
		pause
		
		if convertedTracks is {} then error "Music did not return a converted track."
		
		set convertedTrack to item 1 of convertedTracks
		set convertedTrackLibraryLocation to location of convertedTrack
		
		-- Remove the original imported WAV track from Music.
		delete sourceTrack
	end tell
	
	tell application "Finder"
		-- Move the converted file from Music's output/library location
		-- back into the same folder as the original WAV.
		set movedConvertedFile to move file convertedTrackLibraryLocation to folder originalFolder with replacing
		
		-- Delete the original WAV file.
		delete fileToConvert
		
		-- Save the new final location of the converted file.
		set finalConvertedAlias to movedConvertedFile as alias
		
		-- Empty trash automatically.
		set warns before emptying of trash to false
		empty trash
		set warns before emptying of trash to true
	end tell
	
	tell application "Music"
		-- Update Music so the converted track points to its new file location.
		set location of convertedTrack to finalConvertedAlias
	end tell
	
	return {convertedTrack}
end convertAudioFileInMusic


on addTrackToDerivedPlaylist(trackList)
	tell application "Music"
		set trackLocation to location of item 1 of trackList
	end tell
	
	tell application "Finder"
		set thisFile to file trackLocation
		set parentFolder to container of thisFile
		set grandparentFolder to container of parentFolder

		set parentFolderName to name of parentFolder as text
		set grandparentFolderName to name of grandparentFolder as text
	end tell
	
	set playlistName to parentFolderName & " - " & grandparentFolderName
	
	tell application "Music"
		if exists playlist playlistName then
			duplicate (item 1 of trackList) to playlist playlistName
		else
			set newPlaylist to make new playlist with properties {name:playlistName}
			duplicate (item 1 of trackList) to newPlaylist
			
			-- Store new playlists
			-- inside the "KCIC Music" folder playlist.
			move newPlaylist to folder playlist "KCIC Music"
		end if
	end tell
end addTrackToDerivedPlaylist


on joinList(theList, theDelimiter)
	set oldTIDs to AppleScript's text item delimiters
	set AppleScript's text item delimiters to theDelimiter
	set joinedText to theList as text
	set AppleScript's text item delimiters to oldTIDs
	return joinedText
end joinList
