(*
    Converts selected Finder audio files to MP3 format.

    Uses ffmpeg for .m4a files and sox for other non-MP3 audio files.
    Activates the "Music-env" conda environment before conversion.
    Deletes the original file only after the new MP3 is confirmed to exist.
    Skips files that are already .mp3 and reports any failures at the end.
*)

use AppleScript version "2.4"
use scripting additions

on run
	-- Get the current Finder selection as a list of aliases.
	tell application "Finder"
		set theFileSelection to selection as alias list
	end tell
	
	-- If nothing is selected, stop and notify the user.
	if (count of theFileSelection) is 0 then
		display dialog "Select one or more audio files in Finder first." buttons {"OK"} default button 1
		return
	end if
	
	-- Counters and storage for final reporting.
	set convertedCount to 0
	set skippedCount to 0
	set failedItems to {}
	
	-- Process each selected file one at a time.
	repeat with aFile in theFileSelection
		try
			-- Normalize the file reference and path.
			set aFileAlias to aFile as alias
			set aFilePath to POSIX path of aFileAlias
			
			-- Read the file extension in lowercase for safer comparison.
			set aFileExtension to my getLowercaseExtension(aFileAlias)
			
			-- Skip files that are already MP3.
			if aFileExtension is "mp3" then
				set skippedCount to skippedCount + 1
			else
				-- Build the output path by replacing the current extension with .mp3.
				set newFilePath to my replaceExtensionWithMP3(aFilePath)
				
				-- Safety check:
				-- do not overwrite an MP3 that already exists.
				if my fileExists(newFilePath) then
					error "Target file already exists: " & newFilePath
				end if
				
				-- Build the shell command used for conversion.
				set conversionCommand to my buildConversionCommand(aFilePath, newFilePath, aFileExtension)
				
				-- Run the conversion.
				-- do shell script waits until the command is finished.
				do shell script conversionCommand
				
				-- Only delete the original if the new MP3 really exists.
				if my fileExists(newFilePath) then
					tell application "Finder"
						delete aFileAlias
					end tell
					set convertedCount to convertedCount + 1
				else
					error "Conversion finished, but no MP3 was found at: " & newFilePath
				end if
			end if
			
		on error errMsg
			-- Record failures instead of stopping the whole batch.
			set end of failedItems to (aFilePath & " — " & errMsg)
		end try
	end repeat
	
	-- Build a final summary message.
	set reportMessage to "Finished." & return & return & ¬
		"Converted: " & convertedCount & return & ¬
		"Skipped (.mp3): " & skippedCount
	
	-- If any files failed, append them to the report.
	if (count of failedItems) is greater than 0 then
		set reportMessage to reportMessage & return & return & "Failed:" & return & my joinList(failedItems, return)
	end if
	
	-- Show the final report.
	display dialog reportMessage buttons {"OK"} default button 1
end run

on getLowercaseExtension(aFileAlias)
	-- Ask Finder for the file extension.
	tell application "Finder"
		set ext to name extension of aFileAlias
	end tell
	
	-- If there is no extension, return an empty string.
	if ext is missing value or ext is "" then return ""
	
	-- Convert the extension to lowercase using the shell.
	return do shell script "printf %s " & quoted form of ext & " | tr '[:upper:]' '[:lower:]'"
end getLowercaseExtension

on replaceExtensionWithMP3(aFilePath)
	-- Replace the final extension in a POSIX path with ".mp3".
	-- Example:
	-- /Users/name/song.wav -> /Users/name/song.mp3
	
	set oldTIDs to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "."
	set pathParts to text items of aFilePath
	
	-- If there is no dot in the filename, just append .mp3.
	if (count of pathParts) is less than 2 then
		set AppleScript's text item delimiters to oldTIDs
		return aFilePath & ".mp3"
	end if
	
	-- Rebuild everything except the final extension.
	set AppleScript's text item delimiters to "."
	set basePath to (items 1 thru -2 of pathParts) as text
	set AppleScript's text item delimiters to oldTIDs
	
	return basePath & ".mp3"
end replaceExtensionWithMP3

on buildConversionCommand(sourcePath, targetPath, fileExtension)
	-- Build the shell code needed to initialize conda and activate Music-env.
	-- This tries a few common conda install locations.
	set condaSetup to "if [ -f \"$HOME/miniconda3/etc/profile.d/conda.sh\" ]; then source \"$HOME/miniconda3/etc/profile.d/conda.sh\"; " & ¬
		"elif [ -f \"$HOME/anaconda3/etc/profile.d/conda.sh\" ]; then source \"$HOME/anaconda3/etc/profile.d/conda.sh\"; " & ¬
		"elif command -v conda >/dev/null 2>&1; then true; " & ¬
		"else echo \"Conda initialization script not found.\" >&2; exit 1; fi; " & ¬
		"conda activate Music-env"
	
	-- Use ffmpeg for .m4a files, preserving your original workflow.
	-- -n prevents overwriting an existing output file.
	if fileExtension is "m4a" then
		set toolCommand to "ffmpeg -n -i " & quoted form of sourcePath & " -ar 16000 " & quoted form of targetPath
	else
		-- Use sox for all other non-MP3 file types.
		set toolCommand to "sox " & quoted form of sourcePath & " " & quoted form of targetPath
	end if
	
	-- Run everything inside bash -lc so that shell initialization and conda activation work correctly.
	return "bash -lc " & quoted form of (condaSetup & " && " & toolCommand)
end buildConversionCommand

on fileExists(thePath)
	-- Return true if the file exists, otherwise false.
	try
		do shell script "test -e " & quoted form of thePath
		return true
	on error
		return false
	end try
end fileExists

on joinList(theList, theDelimiter)
	-- Join a list of strings into one string with a delimiter.
	set oldTIDs to AppleScript's text item delimiters
	set AppleScript's text item delimiters to theDelimiter
	set joinedText to theList as text
	set AppleScript's text item delimiters to oldTIDs
	return joinedText
end joinList
