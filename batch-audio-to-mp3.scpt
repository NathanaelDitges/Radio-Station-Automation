(*
    Converts selected Finder audio files to MP3.

    Uses ffmpeg for .m4a files and sox for other non-MP3 audio files.
    Activates the "Music-env" conda environment in Terminal first.
    Deletes the original file after the MP3 conversion finishes.

    TODO:
    Priority --- Do not delete the original unless the new .mp3 actually exists.
    Remove Temp script (window 1 in Terminal)
    Possible uppercase extensions

    Clean up ---
    check for ffmpeg and sox (do they exist?!)
    Make summary dialog at end
*)

use AppleScript version "2.4" -- Requires Yosemite (10.10) or later
use scripting additions

on run
	tell application "Finder"
		-- Get the files currently selected in Finder.
		set theFileSelection to the selection
		
		tell application "Terminal"
			activate
			-- do script "echo ''"
			
			-- Activate the conda environment that contains the needed audio tools.
			do script "conda activate Music-env" in window 1
		end tell
		
		-- Process each selected file one at a time.
		repeat with aFile in theFileSelection
			-- Get the file name and extension.
			set aFile_name to name of aFile
			set aFile_type to "." & name extension of aFile
			
			-- Skip files that are already MP3.
			if aFile_type is not ".mp3" then
				-- Convert the Finder item into a POSIX path.
				set aFile_path to POSIX path of (aFile as alias)
				
				-- Find where the extension begins in the full path.
				set y to offset of aFile_type in aFile_path
				
				-- Remove the original extension from the path.
				set aFile_folder to (text 1 thru (y - 1) of aFile_path)
				
				-- Build the output file path with a .mp3 extension.
				set newFile_path to (aFile_folder & ".mp3")
				
				-- Use ffmpeg for .m4a files and resample to 16 kHz.
				if aFile_type is ".m4a" then
					set theScript to "ffmpeg -i " & quoted form of aFile_path & " -ar 16000 " & quoted form of newFile_path
				else
					-- Use sox for other non-MP3 audio files.
					set theScript to "sox " & quoted form of aFile_path & space & quoted form of newFile_path
				end if
				
				tell application "Terminal"
					-- Run the conversion command in Terminal window 1.
					do script theScript in window 1
					
					-- Give the command a moment to begin.
					delay 3
					
					-- Wait until Terminal is no longer busy.
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
