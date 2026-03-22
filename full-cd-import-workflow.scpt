(*
    Imports and processes tracks from an audio CD.

    Converts CD tracks, trims silence with sox, renames and relocates the
    resulting files into a song-type destination folder, updates Music/iTunes
    and Sound Studio metadata, builds or updates a CDPedia XML entry for the
    album, creates a playlist for the import, and ejects the CD when the
    workflow completes successfully.
*)

use AppleScript version "2.4" -- Requires Yosemite (10.10) or later
use scripting additions
use script "Dialog Toolkit Plus" version "1.1.0"

#<--------- Settings ------------------------->#
property Song_Type : "Vocal" -- (Instrumental | Vocal)

-- Default text and default button behavior for the CD-type dialog.
-- Example: {"Solo", 0}
-- 1st item = default text
-- 2nd item = affects which button is default
property Normal_Answer_forCD_Type : {"Solo", 0} -- {(Choir|Trio|Octavo|Quartet), (1:not to import XML is default |0: import to XML is default)}

-- If true, wipe/reset the XML file before saving.
property importresetXML_File : false -- (true | false)

-- If true, only work on the selected tracks rather than the full enabled CD.
-- In this mode XML is not intended to be created.
property runOnly_Selected : false -- (true | false) This does not create XML Files.

-- If true, skip conversion and use the selected tracks as-is.
-- Requires runOnly_Selected to also be true.
property run_withNo_convertion : false -- runOnly_Selected must be true for this to work
#<--------- Settings ------------------------->#


on run
	-- Guard value used to decide whether the CD may be ejected at the end.
	-- It becomes {} when track relocation succeeds.
	set Bad_Test_noCDejct to "Incomplete" -- This will become null and accept CD ejection when all songs are imported correctly
	
	-- Destination folder for processed songs.
	set theDestenation_Location to POSIX path of ("/Volumes/BeatDrop/" & Song_Type & "/")
	
	tell application "Script Debugger"
		-- Get the first audio CD source and its main CD playlist.
		set theCD to first «class cSrc» whose «class pKnd» is «constant eSrckACD»
		set theCD_playlist to «class cCDP» 1 of theCD
		
		-- Read album-level metadata from the CD.
		set {art, alb, cmpsr} to {«class pArt» of theCD_playlist, name of theCD_playlist, «class pCmp» of theCD_playlist}
		
		-- Collect all enabled CD tracks.
		set theTracks_to_Import to every «class cTrk» of theCD_playlist whose «class enbl» is true
		
		-- Tracks the user selected as "bad" / unchecked music.
		set theBad_Music_Tracks to {}
		
		-- Build a list of selected track numbers.
		repeat with aTrack_to_Import in selection
			set end of theBad_Music_Tracks to «class pTrN» of aTrack_to_Import & ", "
		end repeat
		
		-- Start building the dialog buttons.
		set thePressable_Buttons to {"Cancel"}
		set Bad_Music_Comment to false
		
		-- If there are selected "bad" tracks, build the XML note string.
		if theBad_Music_Tracks is not {} then
			set theXML_CustomText1_String to "Not: #"
			repeat with aBad_Music_Track in theBad_Music_Tracks
				set theXML_CustomText1_String to theXML_CustomText1_String & aBad_Music_Track
			end repeat
			
			-- Trim the trailing comma-space and add a semicolon.
			set theXML_CustomText1_String to (text 1 thru -3 of theXML_CustomText1_String) & ";"
			set Bad_Music_Comment to true
		else
			-- If no bad tracks were marked, default to "All Good".
			set theXML_CustomText1_String to "All Good"
		end if
		
		-- Add dialog buttons depending on mode.
		set end of thePressable_Buttons to "Completed"
		if runOnly_Selected is false then
			set end of thePressable_Buttons to "Import"
		end if
		
		-- Calculate which button should be default.
		set Button_Count to (count items in thePressable_Buttons) - (last item in Normal_Answer_forCD_Type)
		
		-- Build a Dialog Toolkit Plus accessory view.
		set accViewWidth to 350
		set {theButtons, minWidth} to «event !ASc!CbS» thePressable_Buttons given «class dflt»:Button_Count, «class cbtn»:1
		if minWidth > accViewWidth then set accViewWidth to minWidth -- Make sure buttons fit.
		
		-- Create text field for CD type comments.
		set {theField, theTop} to «event !ASuCrTf» (first item in Normal_Answer_forCD_Type) given «class !FpL»:(first item in Normal_Answer_forCD_Type), «class !BtM»:0, «class !FwI»:accViewWidth, «class !ExH»:7
		
		-- Create label for CD type comments.
		set {theboldLabel, theTop} to «event !ASuCrLa» "Would you like to add comments to the CD Ablum type?" & return & "For Example: Choir or Trio" given «class !BtM»:theTop + 20, «class !MxW»:accViewWidth, «class !MuS»:«constant !CsZ!CrL»
		
		set theContent_Viewed to {theField, theboldLabel}
		
		-- If there are bad tracks, add a second text field for comments.
		if Bad_Music_Comment is true then
			set {the2Field, theTop} to «event !ASuCrTf» "" given «class !BtM»:theTop + 20, «class !FwI»:accViewWidth, «class !ExH»:7
			set {the2boldLabel, theTop} to «event !ASuCrLa» "Would you like to add comments to the Unchecked Music list?" given «class !BtM»:theTop + 20, «class !MxW»:accViewWidth, «class !MuS»:«constant !CsZ!CrL»
			set end of theContent_Viewed to the2Field
			set end of theContent_Viewed to the2boldLabel
		end if
		
		-- Show the custom dialog.
		set {buttonName, controlsResults} to «event !AScDiEw» "KCIC CD Import Settings" with «class !AvL» given «class !AvW»:accViewWidth, «class !AvH»:theTop, «class !AvC»:theContent_Viewed, «class btns»:theButtons, «class !AcF»:theField, «class !AiP»:{0, 0}
		
		set XML_Completed to false
		
		-- Read the results from the dialog fields.
		set {theBottom_Entry, theTop_Entry} to {first item of controlsResults, item -2 of controlsResults}
		set theAdditional_XML_CD_Type to ""
		
		-- Apply dialog results to XML strings.
		if theBottom_Entry = theTop_Entry and theBottom_Entry is not "" then
			set theAdditional_XML_CD_Type to ", " & (theBottom_Entry)
		else if theBottom_Entry is not theTop_Entry then
			if theBottom_Entry is not "" then
				set theAdditional_XML_CD_Type to ", " & (theBottom_Entry)
			end if
			if theTop_Entry is not "" then
				set theXML_CustomText1_String to theXML_CustomText1_String & " (" & theTop_Entry & ")"
				log theXML_CustomText1_String
			end if
		end if
		
		-- If the user chose Completed, mark XML as completed and clear extra CD type text.
		if buttonName = "Completed" then
			set XML_Completed to true
			log XML_Completed
			set theAdditional_XML_CD_Type to ""
		end if
		
		-- Convert or select tracks according to the chosen mode.
		set theTracks_Converted to {}
		if run_withNo_convertion is false then
			if runOnly_Selected is false then
				-- Normal mode: convert all enabled CD tracks.
				repeat with aTrack_to_Import in theTracks_to_Import
					set end of theTracks_Converted to first item of («event hookConv» aTrack_to_Import)
				end repeat
			else
				-- Selection-only mode: convert only the selected tracks.
				display alert "Converting Selection"
				repeat with aTrack_to_Import in selection
					set end of theTracks_Converted to first item of («event hookConv» aTrack_to_Import)
				end repeat
			end if
		else if runOnly_Selected is true then
			-- No-conversion mode: use the selected tracks directly.
			display alert "You are not converting these tracks"
			repeat with aTrack_to_Import in selection
				set end of theTracks_Converted to aTrack_to_Import
			end repeat
		else
			-- Invalid mode combination.
			display alert "You must Select a section in the library to be run (possibly the CD needs to be inserted)"
		end if
		
		# -- my personal_notification(alb & ": Imported")
		
		if theTracks_Converted is not {} then
			-- Create a playlist for the imported/processed album.
			set aNew_Playlist to (make new «class cPly» with properties {name:(art & " - " & alb)})
			
			-- This accumulates the per-track XML.
			set thePreped_Track_XML to {}
			
			-- Album-level XML data that will later be expanded.
			set theAlbum_Rquired_XMLData to {Song_Type, art, alb, cmpsr, theXML_CustomText1_String, theAdditional_XML_CD_Type}
			
			repeat with aConverted_Track in theTracks_Converted
				-- Duplicate the track into the playlist.
				duplicate aConverted_Track to aNew_Playlist
				
				-- Read track metadata.
				set {nom, alb, art, trknum} to {name, «class pAlb», «class pArt», «class pTrN»} of aConverted_Track
				
				-- Replace slashes in the track name so it is safer as a filename.
				repeat while nom contains "/"
					set y to offset of "/" in nom
					set nom to (text 1 thru (y - 1) of nom) & "-" & (text (y + 1) thru -1 of nom)
				end repeat
				
				-- Write updated metadata into the library track.
				set name of aConverted_Track to nom
				set «class pCmt» of aConverted_Track to Song_Type
				set «class pArt» of aConverted_Track to (art & " - " & alb)
				
				delay 1
				
				-- Save original file location.
				set theSong_Location to get «class pLoc» of aConverted_Track
				set theDelete_Location to get «class pLoc» of aConverted_Track
				
				tell application "Finder"
					-- Read the current file extension.
					set theSong_Extension to name extension of theSong_Location
					
					-- Build the new filename: Album_TrackNumber_SongName.ext
					set theSong_Name to (alb & "_" & trknum & "_" & nom) as string
					repeat while theSong_Name contains ":"
						set y to offset of ":" in theSong_Name
						set theSong_Name to (text 1 thru (y - 1) of theSong_Name) & "_" & (text (y + 1) thru -1 of theSong_Name)
					end repeat
					
					-- Build destination output path.
					set theNew_Song_Location to theDestenation_Location & theSong_Name & "." & theSong_Extension
					
					-- Convert source path to POSIX string.
					set theSong_Location to POSIX path of theSong_Location
					
					-- Build the sox command:
					-- trim silence, reverse-trim-reverse, and pad both ends.
					set Single_SoxCmd to ("sox \"" & theSong_Location & "\" \"" & theNew_Song_Location & "\" silence 1 0.5 0.5% reverse silence 1 0.5 0.5% reverse pad 0.5 0.5") as string
					
					-- Escape exclamation points for shell use.
					repeat while Single_SoxCmd contains "!"
						set y to offset of "!" in Single_SoxCmd
						set Single_SoxCmd to (text 1 thru (y - 1) of Single_SoxCmd) & ":ReplaceExl:" & (text (y + 1) thru -1 of Single_SoxCmd)
					end repeat
					repeat while Single_SoxCmd contains ":ReplaceExl:"
						set y to offset of ":ReplaceExl:" in Single_SoxCmd
						set z to count ":ReplaceExl:"
						set Single_SoxCmd to (text 1 thru (y - 1) of Single_SoxCmd) & "\\!" & (text (y + z) thru -1 of Single_SoxCmd)
					end repeat
					
					tell application "Terminal"
						-- Run sox and wait for it to finish.
						set frontWindow to do script Single_SoxCmd in window 1
						repeat
							delay 1
							if not busy of frontWindow then exit repeat
						end repeat
					end tell
					
					if theSong_Extension is not "" then
						-- Build a loose search name for later library matching.
						set theSearch_Name to text 1 thru -2 of nom
						set theSong_Extension to ("." & theSong_Extension)
					end if
					
					-- Delete the original converted file and empty trash.
					delete theDelete_Location
					empty the trash
					
				end tell
				
				-- Escape exclamation points in the destination path.
				repeat while theNew_Song_Location contains "!"
					set y to offset of "!" in theNew_Song_Location
					set theNew_Song_Location to (text 1 thru (y - 1) of theNew_Song_Location) & ":replace:" & (text (y + 1) thru -1 of theNew_Song_Location)
				end repeat
				repeat while theNew_Song_Location contains ":replace:"
					set y to offset of ":replace:" in theNew_Song_Location
					set z to count ":replace:"
					set theNew_Song_Location to (text 1 thru (y - 1) of theNew_Song_Location) & "\\!" & (text (y + z) thru -1 of theNew_Song_Location)
				end repeat
				
				-- Find matching library tracks and repoint them to the processed file.
				repeat with aiTunes_Track in (every «class cFlT» whose name contains theSearch_Name and «class pArt» contains alb)
					try
						set «class pLoc» of aiTunes_Track to POSIX file (theNew_Song_Location)
						set Bad_Test_noCDejct to {}
					on error errTxt
						my sendPush_notification(theNew_Song_Location & ": Error")
						set Bad_Test_noCDejct to errTxt
					end try
				end repeat
				
				-- Gather metadata for writing back into the final audio file.
				set aTracks_Required_Metadata to {¬
					«class pLoc», ¬
					name, ¬
					«class pArt», ¬
					«class pCmt» ¬
						} of aiTunes_Track
				set aTracks_Album_Metadata to {«class pAlb»} of aiTunes_Track
				set aTracks_Track_Number_Metadata to {«class pTrN»} of aiTunes_Track
				set aTracks_Track_Count_Metadata to {«class pTrC»} of aiTunes_Track
				set aTracks_Year_Metadata to {«class pYr »} of aiTunes_Track
				set aTracks_Composer_Metadata to {«class pCmp»} of aiTunes_Track
				
				log «class pLoc» of aiTunes_Track
				
				-- Make sure required metadata exists.
				if (count aTracks_Required_Metadata) is not 4 then return display dialog ¬
					"Does not have title, artist, or comments!" with title ¬
					"Add Metadata To Sound Studio File" buttons ¬
					{"Haha, Try Again!"}
				
				tell application "Sound Studio"
					-- Open the processed file.
					set aSong_Location to {}
					set aSong_Location to the first item of aTracks_Required_Metadata
					set D to open POSIX path of (aSong_Location)
					
					-- Write core metadata.
					tell the metadata of D to set {¬
						title, ¬
						artist, ¬
						comments ¬
							} to the rest of aTracks_Required_Metadata
					
					-- Write optional metadata where available.
					try
						tell the metadata of D to set {album} to aTracks_Album_Metadata
					end try
					try
						tell the metadata of D to set {track number} to aTracks_Track_Number_Metadata
					end try
					try
						tell the metadata of D to set {track total} to aTracks_Track_Count_Metadata
					end try
					try
						tell the metadata of D to set {year} to aTracks_Year_Metadata
					end try
					try
						tell the metadata of D to set {composer} to aTracks_Composer_Metadata
					end try
					
					-- Force genre.
					tell the metadata of D to set genre to ("Religious")
					
					save D
					close D
					log D
				end tell
				
				-- Convert track duration to mm:ss for XML.
				set dur to («class pDur» of aConverted_Track) as integer
				set durmin to (dur div minutes) as integer
				set dursec to (dur mod minutes) as integer
				if (count (dursec as string)) as integer = 1 then set dursec to "0" & dursec
				set dur to (durmin & ":" & dursec) as string
				
				-- Package this track's XML data.
				set aTracks_Required_XMLdata to {¬
					art, ¬
					dur, ¬
					nom, ¬
					trknum ¬
						}
				set thePreped_Track_XML to my setTrack_XML_for(aTracks_Required_XMLdata, thePreped_Track_XML)
			end repeat
			
			-- Add total track count to the album XML data.
			set end of theAlbum_Rquired_XMLData to {«class pTrC»} of first item in theTracks_Converted
			
			-- Open the XML tree for the chosen song type.
			set theXML_Tree to my getXML_Root_from(Song_Type)
			if importresetXML_File is false then
				-- Get the next album key and see whether the album is already present.
				set end of theAlbum_Rquired_XMLData to my getLast_Album_Number_in(theXML_Tree)
				set find_Album_XML to my checkAlbum_XML_inCDpedia(theAlbum_Rquired_XMLData)
				
				if find_Album_XML is false then
					-- Notify if XML completion state and existing XML state conflict.
					if XML_Completed is not find_Album_XML then
						my sendPush_notification("Double Check XML File for " & alb)
						log ("Alert: Double Check XML File for " & alb)
					end if
					
					-- Only add XML when not marked completed.
					if XML_Completed is false then
						my addAlbum_XML_to(theXML_Tree, theAlbum_Rquired_XMLData, thePreped_Track_XML)
						my saveNew_XML_Tree(theXML_Tree, Song_Type)
					end if
				end if
			else
				-- Reset then save the XML file.
				my resetXML_for_Import(theXML_Tree, Song_Type)
				my saveNew_XML_Tree(theXML_Tree, Song_Type)
			end if
		end if
		
		-- Move the playlist into the folder playlist named after Song_Type.
		move aNew_Playlist to «class cFoP» Song_Type
		
		-- If everything succeeded, eject the CD and notify the user.
		if Bad_Test_noCDejct is {} then
			«event aevtejct»
			my personal_notification(alb & ": Complete")
			my sendPush_notification(alb & " is Complete")
			return (alb & ": Complete")
		end if
	end tell
end run

to personal_notification(textMessage)
	-- Send an iMessage.
	tell application "Messages"
		set targetBuddy to "+19702349148"
		set targetService to id of 1st account whose service type = iMessage
		
		set theBuddy to participant targetBuddy of account id targetService
		send textMessage to theBuddy
	end tell
end personal_notification

on replaceCharacter(thisCharacter, With_thisCharacter, In_thisText)
	-- Replace all instances of one character/string with another.
	set ReplaceText to "::::"
	if ReplaceText contains thisCharacter then
		set ReplaceText to "ReplacementText"
	end if
	
	repeat while In_thisText contains thisCharacter
		set y to offset of thisCharacter in In_thisText
		set In_thisText to (text 1 thru (y - 1) of In_thisText) & ReplaceText & (text (y + 1) thru -1 of In_thisText)
	end repeat
	repeat while In_thisText contains ReplaceText
		set y to offset of ReplaceText in In_thisText
		set z to count ReplaceText
		set In_thisText to (text 1 thru (y - 1) of In_thisText) & With_thisCharacter & (text (y + z) thru -1 of In_thisText)
	end repeat
	return In_thisText
end replaceCharacter

on getXML_Root_from(Song_Type)
	-- Open the XML package for the given song type from the desktop.
	set theXML_File to "/Users/nathanaelditges/Desktop/" & Song_Type & ".cdpedia/info.xml"
	set theXML_Tree to «event XML open» theXML_File
	set theXML_Tree_Root to «event XML root» theXML_Tree
	return theXML_Tree_Root
end getXML_Root_from

on getLast_Album_Number_in(theXML_Tree)
	-- Return the highest album key currently in the XML tree.
	set aNew_Album_Key to {}
	set theAlbum_Number to «event XML gttx» («event XML path» theXML_Tree given «class with»:"dict/key")
	try
		set aNew_Album_Key to ((«class mRes» of («event SATIFINd» "\\d*(?=\\.)" with «class UsGR» given «class $in »:(«class MAX » of («event SATIStat» theAlbum_Number) as string))))
	on error
		set aNew_Album_Key to 0
	end try
	return aNew_Album_Key
end getLast_Album_Number_in

on findUncheck_Songs_from(theXML_Tree_Root, withAlbum_Identity)
	-- Find album entries and extract their customText1 bad-track info.
	set theAlbums to {}
	set theUncheced_Track_Numbers to {}
	repeat with anAlbum in («event XML path» theXML_Tree_Root given «class with»:("dict/dict[string=\"" & (withAlbum_Identity) as string) & "\"]")
		«event XML gttx» anAlbum
		set anAlbums_Song_Check to «class mRes» of («event SATIFINd» "(?<=customText1).*(?=dateAdded)" with «class UsGR» given «class $in »:(«event XML gttx» anAlbum))
		if anAlbums_Song_Check contains ";" then
			set anAlbums_Song_Check to «class mRes» of («event SATIFINd» ".*(?=;)" with «class UsGR» given «class $in »:(anAlbums_Song_Check))
		end if
		set anAlbums_Title to «event SATIFINd» "(?<=title).*(?=tracks)" with «class UsGR» given «class $in »:(«event XML gttx» anAlbum)
		set end of theUncheced_Track_Numbers to (anAlbums_Song_Check & ", " & («class mRes» of anAlbums_Title))
	end repeat
	return theUncheced_Track_Numbers
end findUncheck_Songs_from

on addAlbum_XML_to(theXML_Tree, With_thisAlbums_Data, andTrack_XML)
	-- Unpack album-level data for building the XML dictionary.
	set {Song_Type, ¬
		Ablum_Artist, ¬
		Ablum_Name, ¬
		Ablum_Composer, ¬
		Bad_Songs_String, ¬
		Addional_Song_Types, ¬
		Album_Tracks, ¬
		Key_Number ¬
			} to With_thisAlbums_Data
	
	-- Build the XML key and album dictionary block.
	set theKey_Data to "<key>" & ((Key_Number) + 1) & "</key>"
	set theDict_Data to "<dict>
		<key>artist</key>
		<string>" & Ablum_Artist & "</string>
		<key>composer</key>
		<string>" & Ablum_Composer & "</string>
		<key>customCheckbox1</key>
		<integer>0</integer>
		<key>customCheckbox2</key>
		<integer>0</integer>
		<key>customTag1</key>
		<string>" & Song_Type & Addional_Song_Types & "</string>
		<key>customText1</key>
		<string>" & Bad_Songs_String & "</string>
		<key>dateAdded</key>
		<date>2020-03-04T17:11:20Z</date>
		<key>dateEdited</key>
		<date>2020-04-05T13:46:03Z</date>
		<key>discID</key>
		<string>e309290f</string>
		<key>duration</key>
		<string>38:59</string>
		<key>format</key>
		<string>CD</string>
		<key>genre</key>
		<string>Religious</string>
		<key>hasBeenSold</key>
		<integer>0</integer>
		<key>hasMovieLink</key>
		<integer>0</integer>
		<key>itunes</key>
		<integer>0</integer>
		<key>myRating</key>
		<integer>0</integer>
		<key>numberOfTracks</key>
		<string>" & Album_Tracks & "</string>
		<key>onSale</key>
		<integer>0</integer>
		<key>releaseDate</key>
		<date>2013-03-04T19:00:00Z</date>
		<key>status</key>
		<integer>0</integer>
		<key>title</key>
		<string>" & Ablum_Name & "</string>
		<key>tracks</key>
		<array>
			" & andTrack_XML & "
		</array>
		<key>uid</key>
		<integer>105</integer>
		<key>uploaded</key>
		<integer>0</integer>
	</dict>"
	
	-- Escape ampersands before inserting into XML.
	set theDict_Data to my replaceCharacter("&", "&amp;", theDict_Data)
	set theKey_Data to my replaceCharacter("&", "&amp;", theKey_Data)
	
	-- Insert XML depending on the current album key count.
	if (Key_Number) as integer = 0 then
		set theDictionary_Level to «event XML path» theXML_Tree given «class with»:"dict"
		log ("XMLKey " & Key_Number & "-1dict")
		log («event XML disp» theDictionary_Level)
		set theNew_Album_key to «event XML addc» theKey_Data given «class at  »:theDictionary_Level
		set theAlbum_Level to «event XML path» theXML_Tree given «class with»:"dict/key"
		log ("1alblvl ")
		log («event XML disp» theAlbum_Level)
		set theNew_Album_dict to «event XML adds» theDict_Data given «class afte»:theAlbum_Level
	else if ((Key_Number) as integer) = 1 then
		set theAlbum_Level to «event XML path» theXML_Tree given «class with»:"dict/dict"
		log ("XMLKey " & Key_Number & "-2 ")
		log («event XML disp» theAlbum_Level)
		set theNew_Album_dict to «event XML adds» theDict_Data given «class afte»:theAlbum_Level
		set theNew_Album_key to «event XML adds» theKey_Data given «class afte»:theAlbum_Level
	else
		set theAlbum_Level to «event XML path» theXML_Tree given «class with»:"dict/dict"
		log ("XMLKey " & Key_Number & "-3 ")
		log («event XML disp» theAlbum_Level)
		set theNew_Album_dict to «event XML adds» theDict_Data given «class afte»:(last item in theAlbum_Level)
		set theNew_Album_key to «event XML adds» theKey_Data given «class afte»:(last item in theAlbum_Level)
	end if
	return theXML_Tree
end addAlbum_XML_to

on checkAlbum_XML_inCDpedia(With_thisAlbums_Data)
	-- Check whether the album already exists in the Complete XML library.
	set theXML_Tree to my getXML_Root_from("Complete")
	set {Song_Type, ¬
		Ablum_Artist, ¬
		Ablum_Name, ¬
		Ablum_Composer, ¬
		Bad_Songs_String, ¬
		Addional_Song_Types, ¬
		Album_Tracks, ¬
		Key_Number ¬
			} to With_thisAlbums_Data
	
	set XML_track_found to false
	repeat with anIdentifyed_Ablum in «event XML path» theXML_Tree given «class with»:("dict/dict[string=\"" & ((Ablum_Name) as string) & "\"]")
		set anIdentifyed_Ablums_Text to «event XML gttx» anIdentifyed_Ablum
		
		set y to count Ablum_Artist
		set checkAlbums_Artist to «class mRes» of («event SATIFINd» "(?<=artist).{" & y & "}" with «class UsGR» given «class $in »:(anIdentifyed_Ablums_Text))
		
		set x to count (Album_Tracks as string)
		set checkAlbums_Track_Count to «class mRes» of («event SATIFINd» "(?<=numberOfTracks).{" & x & "}" with «class UsGR» given «class $in »:(anIdentifyed_Ablums_Text))
		
		log checkAlbums_Artist & ", " & Ablum_Artist & ", " & checkAlbums_Track_Count & ", " & Album_Tracks
		if checkAlbums_Artist contains Ablum_Artist and checkAlbums_Track_Count contains Album_Tracks then
			set XML_track_found to true
			log XML_track_found
		end if
	end repeat
	return XML_track_found
end checkAlbum_XML_inCDpedia

on setTrack_XML_for(thisTracks_data, After_thisXML)
	-- Append one track dictionary block to the XML track list.
	set {¬
		art, ¬
		dur, ¬
		nom, ¬
		tknum ¬
			} to thisTracks_data
	log dur
	
	if last item in thisTracks_data is 1 then
		set theTracks_Full_XML to "<dict>
			<key>artist</key>
			<string>" & art & "</string>
			<key>duration</key>
			<string>" & dur & "</string>
			<key>name</key>
			<string>" & nom & "</string>
			<key>position</key>
			<integer>" & (tknum - 1) & "</integer>
		</dict>"
	else
		set theTracks_Full_XML to After_thisXML & "
		<dict>
		<key>artist</key>
		<string>" & art & "</string>
		<key>duration</key>
		<string>" & dur & "</string>
		<key>name</key>
		<string>" & nom & "</string>
		<key>position</key>
		<integer>" & (tknum - 1) & "</integer>
	</dict>"
	end if
	return theTracks_Full_XML
end setTrack_XML_for

on saveNew_XML_Tree(theXML_Tree, Song_Type)
	-- Save the XML tree back to the desktop CDPedia package.
	set tothePath to ((path to desktop) as Unicode text) & Song_Type & ".cdpedia:info.xml"
	«event XML save» theXML_Tree given «class kfil»:file tothePath
	set the_file to tothePath as alias
end saveNew_XML_Tree

on resetXML_for_Import(theXML_Tree, Song_Type)
	-- Open the CDPedia package and remove its main dictionary contents.
	tell application "Finder" to open file ((path to desktop folder as text) & Song_Type & ".cdpedia") using ((path to applications folder as text) & "CDpedia.app")
	delay 3
	set theDictionary_Level to «event XML path» theXML_Tree given «class with»:"dict"
	«event XML remc» of theDictionary_Level
	return theXML_Tree
end resetXML_for_Import

on sendPush_notification(theSubject)
	-- Send an email to IFTTT as a push trigger.
	tell application "Mail"
		##Create the message
		set theMessage to make new outgoing message with properties {sender:"nathanael.ditges@bcmedu.org", subject:(theSubject & " #Automator")}
		
		##Set a recipient
		tell theMessage
			make new to recipient with properties {address:"trigger@applet.ifttt.com"}
			
			##Send the Message
			send
		end tell
	end tell
end sendPush_notification
