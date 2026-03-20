(*
    Scans selected Finder files and folders for MP3 files.

    Recursively walks through selected folders, collects any .mp3 files
    it finds, and then selects those files in Finder. Useful as a quick
    utility for testing or gathering MP3 files from mixed folder trees.
*)

use AppleScript version "2.4" -- Requires Yosemite (10.10) or later
use scripting additions

on run
	-- Get the current Finder selection.
	tell application "Finder"
		set selectedItems to selection as alias list
	end tell
	
	-- Stop if nothing is selected.
	if (count of selectedItems) is 0 then
		display dialog "Select one or more files or folders in Finder first." buttons {"OK"} default button 1
		return
	end if
	
	-- This list will store every MP3 file found during the scan.
	set foundMP3Files to {}
	
	-- Scan each selected item.
	repeat with anItem in selectedItems
		set foundMP3Files to foundMP3Files & my collectMP3Files(anItem as alias)
	end repeat
	
	-- If no MP3 files were found, let the user know.
	if foundMP3Files is {} then
		display dialog "No MP3 files were found in the current selection." buttons {"OK"} default button 1
		return
	end if
	
	-- Select all found MP3 files in Finder.
	tell application "Finder"
		select foundMP3Files
	end tell
end run


on collectMP3Files(anItem)
	-- Returns a list of MP3 file aliases found in the item.
	-- If the item is a folder, scan it recursively.
	-- If the item is a file, return it only if it is an MP3.
	
	tell application "Finder"
		set itemClass to class of anItem
	end tell
	
	if itemClass is folder then
		return my collectMP3FilesFromFolder(anItem)
	else
		return my classifyMP3File(anItem)
	end if
end collectMP3Files


on collectMP3FilesFromFolder(folderAlias)
	-- Recursively scan a folder and all its subfolders for MP3 files.
	set foundFiles to {}
	
	tell application "Finder"
		-- Check files directly inside this folder.
		try
			set directFiles to every file of folderAlias
			repeat with aFile in directFiles
				set foundFiles to foundFiles & my classifyMP3File(aFile as alias)
			end repeat
		end try
		
		-- Recurse into subfolders.
		try
			set subFolders to every folder of folderAlias
			repeat with aSubFolder in subFolders
				set foundFiles to foundFiles & my collectMP3FilesFromFolder(aSubFolder as alias)
			end repeat
		end try
	end tell
	
	return foundFiles
end collectMP3FilesFromFolder


on classifyMP3File(fileAlias)
	-- Return the file in a one-item list if it is an MP3.
	-- Otherwise return an empty list.
	
	tell application "Finder"
		set ext to name extension of fileAlias
	end tell
	
	if ext is missing value then set ext to ""
	set ext to do shell script "printf %s " & quoted form of ext & " | tr '[:upper:]' '[:lower:]'"
	
	if ext is "mp3" then
		return {fileAlias}
	else
		return {}
	end if
end classifyMP3File
