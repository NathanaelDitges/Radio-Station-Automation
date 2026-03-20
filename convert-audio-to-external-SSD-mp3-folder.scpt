(*
    Scans selected Finder files and folders for supported audio files.

    Collects .wav, .m4a, and .wma files, converts them to MP3,
    and can optionally place all output files into a fixed destination folder.
    Existing MP3 files can also be moved into that same folder.
    Includes optional source-file deletion and optional preview playback.
*)

use AppleScript version "2.4" -- Requires Yosemite (10.10) or later
use scripting additions

-- Global state used during scanning and conversion.
property FoundFile : false -- Intended as an early-stop flag.
property FoundFiles : {} -- Stores files found for conversion.

property NoMusic : true -- If false, preview-play the first converted file.
property NoDelete : true -- If false, delete original source files after conversion.

property useSetPath : true -- If true, place converted/output MP3 files in a fixed folder.
property SetPath : "/Volumes/T7 Shield/KCIC Radio Library_2023/Previously used Message/Psr David_Pear Park Baptist/"
property setfilepath : alias "T7 Shield:KCIC Radio Library_2023:Previously used Message:Psr David_Pear Park Baptist"

property SampleRate : "16000" -- Output sample rate. Example alternative: "44100"

on run
	
	tell application "Finder"
		
		-- Get the current Finder selection.
		set theSelection to selection
		
		-- Process each selected item.
		repeat with anItem_Selected in theSelection
			
			if (class of anItem_Selected) is folder then
				
				-- Stop if the script has been flagged to stop early.
				if FoundFile is true then exit repeat
				
				-- Recursively scan the selected folder.
				my FolderTree_FindFiles(anItem_Selected)
				
			else if (class of anItem_Selected) is document file then
				
				-- Stop if the script has been flagged to stop early.
				if FoundFile is true then exit repeat
				
				-- Check a single selected file.
				my FileFound_ExCheck(anItem_Selected)
				
			end if
			
		end repeat
		
		-- If matching files were found, reveal them in Finder,
		-- convert them, then clean up state.
		if FoundFiles is not {} then
			
			set SelectedFiles to reveal FoundFiles
			
			my BatchConvert_toMP3(SelectedFiles)
			
			-- Close the Finder window used/reused by reveal.
			close window 1
			
			-- Reset the found-file list.
			set FoundFiles to {}
			
		end if
		
	end tell
	
end run


on FolderTree_FindFiles(anItem_Selected)
	
	tell application "Finder"
		
		-- Get direct subfolders and direct files from the current folder.
		set theFolders_Selected to every folder in anItem_Selected
		set theFiles_Selected to every file in anItem_Selected
		
		-- Recurse into each subfolder.
		repeat with aFolder_Selected in theFolders_Selected
			
			if FoundFile is true then exit repeat
			
			my FolderTree_FindFiles(aFolder_Selected)
			
		end repeat
		
		-- Check each file directly inside the current folder.
		repeat with aFile_Selected in theFiles_Selected
			
			if FoundFile is true then exit repeat
			
			my FileFound_ExCheck(aFile_Selected)
			
		end repeat
		
		-- If files were found during this scan stage, reveal and convert them immediately.
		if FoundFiles is not {} then
			
			set SelectedFiles to reveal FoundFiles
			
			my BatchConvert_toMP3(SelectedFiles)
			
			close window 1
			
			set FoundFiles to {}
			
		end if
		
	end tell
	
end FolderTree_FindFiles


on FileFound_ExCheck(aFile_Selected)
	
	tell application "Finder"
		
		-- Read the file extension.
		set aFile_NameEx to name extension of aFile_Selected
		
		-- If the file is one of the supported source formats, collect it for conversion.
		if aFile_NameEx is "wav" or aFile_NameEx is "m4a" or aFile_NameEx is "wma" then
			
			set end of FoundFiles to aFile_Selected
			
		-- If the file is already an MP3 and the fixed destination option is enabled,
		-- move the MP3 into the chosen destination folder.
		else if aFile_NameEx is "mp3" and useSetPath is true then
			
			move aFile_Selected to setfilepath
			
		-- If the file is neither MP3 nor one of the supported source types,
		-- reveal it in Finder.
		else if aFile_NameEx is not "mp3" then
			
			reveal aFile_Selected
			
		end if
		
	end tell
	
end FileFound_ExCheck


on BatchConvert_toMP3(SelectedFiles)
	
	tell application "Finder"
		
		-- Use Finder's current selection as the working list.
		-- This assumes "reveal FoundFiles" made the correct files selected.
		set theFileSelection to selection
		
		-- Save the first file name so the script can optionally preview
		-- the first converted file later.
		set fstItemName to name of (get item 1 in theFileSelection)
		
		tell application "Terminal"
			activate
			
			-- Activate the conda environment used for conversion tools.
			set d to do script "conda activate Music-env" in window 1
			delay 0.1
			
			-- Define a VLC alias in the shell for possible use with WMA conversion.
			do script "alias vlc='/Applications/VLC.app/Contents/MacOS/VLC'" in window 1
			
			-- Save the Terminal window ID so it can be closed later if needed.
			set myID to id of front window
			
		end tell
		
		set yesNew to false
		
		-- Convert each selected file.
		repeat with aFile in theFileSelection
			set aFile_name to name of aFile
			set aFile_type to "." & name extension of aFile
			
			-- Skip files already in MP3 format.
			if aFile_type is not ".mp3" then
				set aFile_path to POSIX path of (aFile as alias)
				
				-- Build a default output path by replacing the original extension with .mp3.
				set y to offset of aFile_type in aFile_path
				set aFile_folder to (text 1 thru (y - 1) of aFile_path)
				set newFile_path to (aFile_folder & ".mp3")
				
				-- If fixed output path mode is enabled, write the new MP3
				-- into the configured destination folder instead.
				if useSetPath is true then
					
					set y to offset of aFile_type in aFile_name
					set aFile_name to (text 1 thru (y - 1) of aFile_name)
					set newFile_path to SetPath & aFile_name & ".mp3"
					
				end if
				
				-- Decide which conversion tool/command to use.
				if aFile_type is ".m4a" or aFile_type is ".wma" then
					-- Use ffmpeg for .m4a and .wma in this version.
					set theScript to "ffmpeg -i " & quoted form of aFile_path & " -ar " & SampleRate & space & quoted form of newFile_path
					
				else if aFile_type is ".wma" then
					-- This VLC branch is unreachable as written,
					-- because .wma is already matched in the previous condition.
					set theScript to "vlc " & quoted form of aFile_path & " -I dummy -vvv --sout=" & quote & "#transcode{vcodec=none,acodec=mp3,ab=128,channels=2,samplerate=" & SampleRate & "}:std{access=file,mux=dummy,dst=" & quoted form of newFile_path & "}" & quote & " vlc://quit"
					
				else
					-- Use sox for other supported formats, such as WAV.
					set theScript to "sox " & quoted form of aFile_path & " -r " & SampleRate & space & quoted form of newFile_path
				end if
				
				tell application "Terminal"
					-- Run the conversion command.
					do script theScript in window 1
					delay 3
					
					-- Wait until Terminal finishes the current command.
					repeat while (get busy of window 1) is true
						delay 1
					end repeat
					
					-- Optionally delete the original source file after conversion.
					if NoDelete is false then
						if (get busy of window 1) is false then set theResult to delete aFile
						delay 0.1
					end if
					
					-- Optionally preview-play the first converted file.
					if aFile_name is fstItemName and NoMusic is false then
						set thePlayScript to "play " & quoted form of newFile_path
						do script thePlayScript in d
						set ntw to do script "conda activate Music-env"
						delay 3
						
						set yesNew to true
					end if
					
				end tell
				
			end if
		end repeat
		
		-- If preview playback was started, notify the user and close the playback Terminal window.
		if yesNew is true then
			tell application "Terminal"
				set NoteWords to "Closing the Music Command"
				display notification NoteWords
				say NoteWords
				beep 2
				close window id myID
				delay 3
				tell application "System Events" to keystroke return
			end tell
		end if
	end tell
end BatchConvert_toMP3
