use AppleScript version "2.4" -- Requires Yosemite (10.10) or later
use scripting additions

on run
	-- Ask Finder for the files currently selected by the user.
	tell application "Finder"
		set theFileSelection to the selection
		
		-- Open Terminal and activate the conda environment needed
		-- for the audio-processing tools in this workflow.
		tell application "Terminal"
			activate
			-- do script "echo ''"
			do script "conda activate Music-env" in window 1
		end tell
		
		-- Process each selected file one at a time.
		repeat with aFile in theFileSelection
			-- Get the file name and extension.
			set aFile_name to name of aFile
			set aFile_type to "." & name extension of aFile
			
			-- Skip files that are already MP3.
			if aFile_type is not ".mp3" then
				-- Get the full POSIX path to the selected file.
				set aFile_path to POSIX path of (aFile as alias)
				
				-- Find where the extension appears in the path.
				-- This is used to strip off the original extension.
				set y to offset of aFile_type in aFile_path
				
				-- Build the output path without the original extension.
				set aFile_folder to (text 1 thru (y - 1) of aFile_path)
				
				-- Add the new .mp3 extension.
				set newFile_path to (aFile_folder & ".mp3")
				
				-- If the source file is .m4a, use ffmpeg and resample to 16 kHz.
				if aFile_type is ".m4a" then
					set theScript to "ffmpeg -i " & quoted form of aFile_path & " -ar 16000 " & quoted form of newFile_path
				else
					-- Otherwise use sox for conversion.
					set theScript to "sox " & quoted form of aFile_path & space & quoted form of newFile_path
				end if
				
				tell application "Terminal"
					-- Run the conversion command in Terminal window 1.
					do script theScript in window 1
					
					-- Give Terminal a moment to start the job.
					delay 3
					
					-- Wait until the Terminal window is no longer busy.
					repeat while (get busy of window 1) is true
						delay 1
					end repeat
					
					-- Once conversion is done, delete the original file.
					if (get busy of window 1) is false then set theResult to delete aFile
					delay 0.1
				end tell
			end if
		end repeat
		
		-- tell application "Terminal" to close window 1
		
	end tell
end run
