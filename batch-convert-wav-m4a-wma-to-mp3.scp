(*
    Scans selected Finder files and folders for supported audio files.

    Collects .wav, .m4a, and .wma files, converts them to MP3 using
    ffmpeg, sox, or VLC depending on the source format, and deletes
    the original files after conversion. Stops early if unsupported
    non-MP3 files are encountered during the scan.
*)

use AppleScript version "2.4"
use scripting additions

property NoMusic : true -- Set to false to preview the first converted file after conversion.

on run
	tell application "Finder"
		set selectedItems to selection as alias list
	end tell
	
	if (count of selectedItems) is 0 then
		display dialog "Select one or more files or folders in Finder first." buttons {"OK"} default button 1
		return
	end if
	
	set supportedFiles to {}
	set unsupportedFiles to {}
	
	-- Scan everything the user selected.
	repeat with anItem in selectedItems
		try
			set scanResult to my scanItem(anItem as alias)
			set supportedFiles to supportedFiles & (supportedFiles of scanResult)
			set unsupportedFiles to unsupportedFiles & (unsupportedFiles of scanResult)
		on error errMsg
			set end of unsupportedFiles to ("Scan error: " & errMsg)
		end try
	end repeat
	
	-- Abort if any unsupported non-MP3 files were found.
	if (count of unsupportedFiles) > 0 then
		display dialog "Unsupported non-MP3 files were found. Conversion stopped." & return & return & my joinList(unsupportedFiles, return) buttons {"OK"} default button 1
		return
	end if
	
	if (count of supportedFiles) is 0 then
		display dialog "No .wav, .m4a, or .wma files were found." buttons {"OK"} default button 1
		return
	end if
	
	set convertedCount to 0
	set failedItems to {}
	set firstConvertedPath to missing value
	
	repeat with aFileAlias in supportedFiles
		set sourcePath to ""
		
		try
			set sourcePath to POSIX path of (aFileAlias as alias)
			set fileExtension to my getLowercaseExtension(aFileAlias)
			set newFilePath to my replaceExtensionWithMP3(sourcePath)
			
			-- Do not overwrite an existing MP3.
			if my fileExists(newFilePath) then
				error "Target MP3 already exists: " & newFilePath
			end if
			
			set conversionCommand to my buildConversionCommand(sourcePath, newFilePath, fileExtension)
			do shell script conversionCommand
			
			-- Confirm output exists before deleting the original.
			if my fileExists(newFilePath) then
				tell application "Finder"
					delete (aFileAlias as alias)
				end tell
				
				set convertedCount to convertedCount + 1
				
				if firstConvertedPath is missing value then
					set firstConvertedPath to newFilePath
				end if
			else
				error "Conversion completed, but the MP3 was not created."
			end if
			
		on error errMsg
			if sourcePath is "" then
				set end of failedItems to ("Unknown file — " & errMsg)
			else
				set end of failedItems to (sourcePath & " — " & errMsg)
			end if
		end try
	end repeat
	
	-- Optional preview of the first converted file.
	if NoMusic is false and firstConvertedPath is not missing value then
		try
			do shell script my buildPreviewCommand(firstConvertedPath)
		end try
	end if
	
	set reportMessage to "Finished." & return & return & ¬
		"Converted: " & convertedCount
	
	if (count of failedItems) > 0 then
		set reportMessage to reportMessage & return & return & "Failed:" & return & my joinList(failedItems, return)
	end if
	
	display dialog reportMessage buttons {"OK"} default button 1
end run


on scanItem(anItemAlias)
	-- Returns a record:
	-- {supportedFiles:{...}, unsupportedFiles:{...}}
	
	tell application "Finder"
		set itemClass to class of anItemAlias
	end tell
	
	if itemClass is folder then
		return my scanFolder(anItemAlias)
	else
		return my classifyFile(anItemAlias)
	end if
end scanItem


on scanFolder(folderAlias)
	set foundSupportedFiles to {}
	set foundUnsupportedFiles to {}
	
	tell application "Finder"
		-- Scan files directly inside this folder.
		try
			set directFiles to every file of folderAlias
			repeat with aFile in directFiles
				set fileResult to my classifyFile(aFile as alias)
				set foundSupportedFiles to foundSupportedFiles & (supportedFiles of fileResult)
				set foundUnsupportedFiles to foundUnsupportedFiles & (unsupportedFiles of fileResult)
			end repeat
		end try
		
		-- Recurse into subfolders.
		try
			set subFolders to every folder of folderAlias
			repeat with aSubFolder in subFolders
				set folderResult to my scanFolder(aSubFolder as alias)
				set foundSupportedFiles to foundSupportedFiles & (supportedFiles of folderResult)
				set foundUnsupportedFiles to foundUnsupportedFiles & (unsupportedFiles of folderResult)
			end repeat
		end try
	end tell
	
	return {supportedFiles:foundSupportedFiles, unsupportedFiles:foundUnsupportedFiles}
end scanFolder


on classifyFile(fileAlias)
	set supportedList to {}
	set unsupportedList to {}
	
	tell application "Finder"
		set ext to name extension of fileAlias
	end tell
	
	if ext is missing value then set ext to ""
	set ext to do shell script "printf %s " & quoted form of ext & " | tr '[:upper:]' '[:lower:]'"
	
	if ext is "wav" or ext is "m4a" or ext is "wma" then
		set end of supportedList to fileAlias
	else if ext is not "mp3" then
		set end of unsupportedList to POSIX path of fileAlias
	end if
	
	return {supportedFiles:supportedList, unsupportedFiles:unsupportedList}
end classifyFile


on getLowercaseExtension(aFileAlias)
	tell application "Finder"
		set ext to name extension of aFileAlias
	end tell
	
	if ext is missing value or ext is "" then return ""
	return do shell script "printf %s " & quoted form of ext & " | tr '[:upper:]' '[:lower:]'"
end getLowercaseExtension


on replaceExtensionWithMP3(aFilePath)
	-- Replace the final extension with .mp3
	set oldTIDs to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "."
	set pathParts to text items of aFilePath
	
	if (count of pathParts) < 2 then
		set AppleScript's text item delimiters to oldTIDs
		return aFilePath & ".mp3"
	end if
	
	set AppleScript's text item delimiters to "."
	set basePath to (items 1 thru -2 of pathParts) as text
	set AppleScript's text item delimiters to oldTIDs
	
	return basePath & ".mp3"
end replaceExtensionWithMP3


on buildConversionCommand(sourcePath, targetPath, fileExtension)
	-- Activate conda from common install locations.
	set condaSetup to "if [ -f \"$HOME/miniconda3/etc/profile.d/conda.sh\" ]; then source \"$HOME/miniconda3/etc/profile.d/conda.sh\"; " & ¬
		"elif [ -f \"$HOME/anaconda3/etc/profile.d/conda.sh\" ]; then source \"$HOME/anaconda3/etc/profile.d/conda.sh\"; " & ¬
		"elif command -v conda >/dev/null 2>&1; then true; " & ¬
		"else echo \"Conda initialization script not found.\" >&2; exit 1; fi; " & ¬
		"conda activate Music-env"
	
	if fileExtension is "m4a" then
		set toolCommand to "ffmpeg -n -i " & quoted form of sourcePath & " -ar 16000 " & quoted form of targetPath
	else if fileExtension is "wma" then
		set vlcPath to "/Applications/VLC.app/Contents/MacOS/VLC"
		set toolCommand to quoted form of vlcPath & " " & quoted form of sourcePath & " -I dummy -vvv --sout=" & quote & "#transcode{vcodec=none,acodec=mp3,ab=128,channels=2,samplerate=44100}:std{access=file,mux=dummy,dst=" & targetPath & "}" & quote & " vlc://quit"
	else
		set toolCommand to "sox " & quoted form of sourcePath & " " & quoted form of targetPath
	end if
	
	return "bash -lc " & quoted form of (condaSetup & " && " & toolCommand)
end buildConversionCommand


on buildPreviewCommand(filePath)
	-- Preview the first converted file using sox's play command.
	set condaSetup to "if [ -f \"$HOME/miniconda3/etc/profile.d/conda.sh\" ]; then source \"$HOME/miniconda3/etc/profile.d/conda.sh\"; " & ¬
		"elif [ -f \"$HOME/anaconda3/etc/profile.d/conda.sh\" ]; then source \"$HOME/anaconda3/etc/profile.d/conda.sh\"; " & ¬
		"elif command -v conda >/dev/null 2>&1; then true; " & ¬
		"else echo \"Conda initialization script not found.\" >&2; exit 1; fi; " & ¬
		"conda activate Music-env"
	
	return "bash -lc " & quoted form of (condaSetup & " && play " & quoted form of filePath)
end buildPreviewCommand


on fileExists(thePath)
	try
		do shell script "test -e " & quoted form of thePath
		return true
	on error
		return false
	end try
end fileExists


on joinList(theList, theDelimiter)
	set oldTIDs to AppleScript's text item delimiters
	set AppleScript's text item delimiters to theDelimiter
	set joinedText to theList as text
	set AppleScript's text item delimiters to oldTIDs
	return joinedText
end joinList
