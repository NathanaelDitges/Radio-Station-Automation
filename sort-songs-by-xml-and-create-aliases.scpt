(*
    Sorts selected song files into artist/album alias folders.

    Reads album, track number, and song title from filenames, cross-checks
    the track against iTunes / Music metadata, and looks up flagged track
    numbers from a CDPedia-style XML library. Tracks marked as bad are moved
    to a bad-song folder and aliased into a matching "Bad Songs" folder;
    other tracks receive normal artist/album aliases.
*)

use AppleScript version "2.4"
use scripting additions

property Manual_ErrorScript : "In Remembrance: Hymns For Communion"
property Type_ofSong : "Vocal" -- (Instrumental | Vocal)
property XML_Folder_Type : "Complete"
property File_LocationOf_XML : "/Users/nathanaelditges/Scripts/"

property BadSong_Source_Folder : "BeatDrop:Bad Song List"
property Alias_Root_Folder : "BeatDrop:Alias Songs By Artist"

on run
	tell application "Finder"
		set selectedItems to selection
	end tell
	
	if selectedItems is {} then
		display dialog "Select one or more song files in Finder first." buttons {"OK"} default button 1
		return
	end if
	
	repeat with oneSelectedSong in selectedItems
		try
			my processSelectedSong(oneSelectedSong)
		on error errMsg
			log ("Error processing file: " & errMsg)
		end try
	end repeat
end run


on processSelectedSong(oneSelectedSong)
	tell application "Finder"
		set originalFileName to name of oneSelectedSong
	end tell
	
	-- Pull basic info from the filename.
	set albumNameFromFile to my getFileInfoOf("Album", oneSelectedSong)
	set trackNumberFromFile to my getFileInfoOf("Track_Number", oneSelectedSong)
	set songNameFromFile to my getFileInfoOf("Song Name", oneSelectedSong)
	
	log albumNameFromFile
	
	-- Refine album and artist info using iTunes / Music metadata.
	set albumInfoList to my getiTunesTrackInfoOf("Album", albumNameFromFile, trackNumberFromFile, songNameFromFile)
	set resolvedAlbumName to my firstItemOrFallback(albumInfoList, albumNameFromFile)
	log resolvedAlbumName
	
	set artistInfoList to my getiTunesTrackInfoOf("Artist", resolvedAlbumName, trackNumberFromFile, songNameFromFile)
	set resolvedArtistName to my firstItemOrFallback(artistInfoList, "Unknown Artist")
	log resolvedArtistName
	
	-- Load XML and find the album's flagged / unchecked tracks.
	set xmlRoot to my getXMLRootFrom(XML_Folder_Type, File_LocationOf_XML)
	set rawRemoveMarkers to my findUncheckedSongsFrom(xmlRoot, resolvedAlbumName)
	
	-- Expand the markers into a flat list of track numbers.
	set expandedBadTrackNumbers to my parseBadTrackNumbers(rawRemoveMarkers, resolvedAlbumName, trackNumberFromFile, songNameFromFile)
	log (expandedBadTrackNumbers & " should be: " & rawRemoveMarkers)
	
	-- Decide whether this track belongs in the bad-song flow.
	if expandedBadTrackNumbers contains (trackNumberFromFile as number) then
		my processBadSong(oneSelectedSong, resolvedArtistName, resolvedAlbumName, trackNumberFromFile)
	else
		my processGoodSong(oneSelectedSong, resolvedArtistName, resolvedAlbumName)
	end if
end processSelectedSong


on processBadSong(oneSelectedSong, artistName, albumName, trackNumber)
	tell application "Finder"
		-- Move the original file to the bad-song holding folder.
		set movedSong to move (oneSelectedSong as text) to BadSong_Source_Folder with replacing
	end tell
	
	log ("moved track number: " & (trackNumber as text) & " of " & albumName & " to bad songs folder")
	
	-- Build / create: Alias Songs By Artist > Type > Artist > Album > Bad Songs
	set badSongsFolder to my ensureBadSongsAliasFolder(artistName, albumName)
	
	tell application "Finder"
		set movedFileName to name of movedSong
		set destinationAliasPath to ((badSongsFolder as text) & ":" & movedFileName)
		
		if exists file destinationAliasPath then
			display notification "Dublicate alias of " & movedFileName & " almost created"
			log "Dublicate bad alias of " & movedFileName & " almost created"
		else
			make new alias file at (badSongsFolder as text) to movedSong
		end if
	end tell
end processBadSong


on processGoodSong(oneSelectedSong, artistName, albumName)
	set albumAliasFolder to my ensureAlbumAliasFolder(artistName, albumName)
	
	tell application "Finder"
		set fileNameOnly to name of oneSelectedSong
		set destinationAliasPath to ((albumAliasFolder as text) & ":" & fileNameOnly)
		
		if exists file destinationAliasPath then
			display notification "Dublicate alias of " & fileNameOnly & " almost created"
			log "Dublicate alias of " & fileNameOnly & " almost created"
		else
			make new alias file at (albumAliasFolder as text) to oneSelectedSong
		end if
	end tell
end processGoodSong


on ensureAlbumAliasFolder(artistName, albumName)
	set safeArtistName to my replaceCharacter(":", "/", artistName)
	set safeAlbumName to my replaceCharacter(":", "/", albumName)
	
	tell application "Finder"
		try
			return make new folder at (Alias_Root_Folder & ":" & Type_ofSong & ":" & safeArtistName) with properties {name:safeAlbumName}
		on error
			try
				set artistFolder to make new folder at (Alias_Root_Folder & ":" & Type_ofSong) with properties {name:safeArtistName}
				return make new folder at artistFolder with properties {name:safeAlbumName}
			on error
				return (Alias_Root_Folder & ":" & Type_ofSong & ":" & safeArtistName & ":" & safeAlbumName)
			end try
		end try
	end tell
end ensureAlbumAliasFolder


on ensureBadSongsAliasFolder(artistName, albumName)
	set albumAliasFolder to my ensureAlbumAliasFolder(artistName, albumName)
	
	tell application "Finder"
		try
			return make new folder at albumAliasFolder with properties {name:"Bad Songs"}
		on error
			return ((albumAliasFolder as text) & ":Bad Songs")
		end try
	end tell
end ensureBadSongsAliasFolder


on parseBadTrackNumbers(rawRemoveMarkers, albumName, trackNumber, songName)
	set parsedRanges to {}
	set expandedNumbers to {}
	
	set regexpScript to "(\\d+(\\s?(-\\s?\\d+|[-&]\\s?f{2}))?)(?=(,?(\\s&)?\\s?\\*?(\\d+(\\s?[&-]\\s?(\\d+|f{2}))?))*(\\s(\\?|([Oo].*)?\\(?)|;|$))"
	
	try
		set parsedRanges to («event SATIFINd» regexpScript with «class UsGR», «class WaAl» and «class WaMr» given «class $in »:rawRemoveMarkers, «class synt»:"RUBY")
	on error
		set parsedRanges to {}
	end try
	
	if parsedRanges is {} then return rawRemoveMarkers
	
	repeat with oneRange in the first item of parsedRanges
		if oneRange contains "-" or oneRange contains "&" then
			set numberParts to («event SATIFINd» "(\\d+|f{2})" with «class UsGR», «class WaAl» and «class WaMr» given «class $in »:oneRange)
			
			set startNumber to (first item of numberParts) as number
			
			if last item of numberParts is "ff" then
				set totalTracksList to my getiTunesTrackInfoOf("Total Tracks", albumName, trackNumber, songName)
				set endNumber to my firstItemOrFallback(totalTracksList, startNumber)
			else
				set endNumber to (last item of numberParts) as number
			end if
			
			repeat with n from startNumber to endNumber
				set end of expandedNumbers to n
			end repeat
		else
			set end of expandedNumbers to (oneRange as number)
		end if
	end repeat
	
	if expandedNumbers is {} then
		return rawRemoveMarkers
	else
		return expandedNumbers
	end if
end parseBadTrackNumbers


on getFileInfoOf(infoNeeded, fromThisFileName)
	tell application "Finder"
		set selectedSongName to name of fromThisFileName
		set selectedSongExtension to name extension of fromThisFileName
	end tell
	
	if infoNeeded is "Album" then
		set albumName to «class mRes» of («event SATIFINd» "^.*(?=_\\d)" with «class UsGR» given «class $in »:selectedSongName)
		return albumName
		
	else if infoNeeded is "Track_Number" then
		set trackNumber to «class mRes» of («event SATIFINd» "(?<=_)\\d+(?=_)" with «class UsGR» given «class $in »:selectedSongName)
		return trackNumber as number
		
	else if infoNeeded is "Song Name" then
		if selectedSongExtension is not "" then
			set selectedSongName to text 1 thru -((count selectedSongExtension) + 2) of selectedSongName
			set extractedSongName to «class mRes» of («event SATIFINd» "(?<=(_\\d_)).*|(?<=(_\\d{2}_)).*" with «class UsGR» given «class $in »:selectedSongName)
			return extractedSongName as string
		end if
		
		log "Song name error from file descript"
	end if
end getFileInfoOf


on getXMLRootFrom(songType, fileLocation)
	set xmlFile to fileLocation & songType & ".cdpedia/info.xml"
	set xmlTree to «event XML open» xmlFile
	set xmlTreeRoot to «event XML root» xmlTree
	return xmlTreeRoot
end getXMLRootFrom


on findUncheckedSongsFrom(xmlTreeRoot, albumIdentity)
	set matchingAlbums to («event XML path» xmlTreeRoot given «class with»:("dict/dict[string=\"" & (albumIdentity as text) & "\"]"))
	log albumIdentity
	
	if matchingAlbums is {} then
		repeat with oneAlbumIdentity in albumIdentity
			if matchingAlbums is {} then
				set matchingAlbums to («event XML path» xmlTreeRoot given «class with»:("dict/dict[string=\"" & (oneAlbumIdentity as text) & "\"]"))
				set foundLogValue to oneAlbumIdentity
			else
				exit repeat
			end if
		end repeat
		
		try
			log "found as '" & (foundLogValue as text) & "' in '" & (albumIdentity as text) & "'"
		end try
	end if
	
	set uncheckedTrackNumbers to {}
	repeat with oneAlbum in matchingAlbums
		set albumText to «event XML gttx» oneAlbum
		set albumSongCheck to «class mRes» of («event SATIFINd» "(?<=customText1).*(?=dateAdded)" with «class UsGR» given «class $in »:albumText)
		
		if albumSongCheck contains ";" then
			set albumSongCheck to «class mRes» of («event SATIFINd» ".*(?=;)" with «class UsGR» given «class $in »:albumSongCheck)
		end if
		
		set end of uncheckedTrackNumbers to albumSongCheck
	end repeat
	
	return uncheckedTrackNumbers
end findUncheckedSongsFrom


on replaceCharacter(thisCharacter, withThisCharacter, inThisText)
	set thisCharacter to thisCharacter as text
	set withThisCharacter to withThisCharacter as text
	set inThisText to inThisText as text
	
	set replacementToken to "----"
	if replacementToken contains thisCharacter then set replacementToken to "ReplacementText"
	
	repeat while inThisText contains thisCharacter
		set y to offset of thisCharacter in inThisText
		set inThisText to (text 1 thru (y - 1) of inThisText) & replacementToken & (text (y + 1) thru -1 of inThisText)
	end repeat
	
	repeat while inThisText contains replacementToken
		set y to offset of replacementToken in inThisText
		set z to count replacementToken
		set inThisText to (text 1 thru (y - 1) of inThisText) & withThisCharacter & (text (y + z) thru -1 of inThisText)
	end repeat
	
	return inThisText
end replaceCharacter


on getiTunesTrackInfoOf(infoNeeded, fromThisAlbum, withThisTrackNumber, andSongName)
	tell application "Script Debugger"
		set allITunesTracks to {}
		
		try
			set andSongName to «event SATIRPLl» "\\!" given «class by  »:"!", «class $in »:(andSongName as text)
			set fromThisAlbum to «event SATIRPLl» "_" given «class by  »:"", «class $in »:(fromThisAlbum as text)
			set allITunesTracks to (every «class cFlT» whose «class pTrN» is (withThisTrackNumber as number) and «class pAlb» is fromThisAlbum and name contains andSongName)
		on error
			try
				log fromThisAlbum
				set allITunesTracks to (every «class cFlT» whose «class pTrN» is (withThisTrackNumber as number) and «class pAlb» contains fromThisAlbum and name contains andSongName)
			on error
				set allITunesTracks to my findITunesTracksByFallback(fromThisAlbum, withThisTrackNumber, andSongName)
			end try
		end try
		
		set infoReturned to {}
		
		repeat with oneITunesTrack in allITunesTracks
			if infoNeeded is "Artist" then
				set infoArtist to «class pArt» of oneITunesTrack
				set end of infoReturned to «class mRes» of («event SATIFINd» "^.*?(?=\\s-)" with «class UsGR» given «class $in »:infoArtist)
			else if infoNeeded is "Total Tracks" then
				set end of infoReturned to {«class pTrC»} of oneITunesTrack
			else if infoNeeded is "Year" then
				set end of infoReturned to {«class pYr »} of oneITunesTrack
			else if infoNeeded is "Album" then
				set end of infoReturned to {«class pAlb»} of oneITunesTrack
			end if
		end repeat
		
		return infoReturned
	end tell
end getiTunesTrackInfoOf


on findITunesTracksByFallback(fromThisAlbum, withThisTrackNumber, andSongName)
	tell application "Script Debugger"
		set allITunesTracks to {}
		set foundMatch to false
		
		set albumCounter to (count (fromThisAlbum as text))
		set songNameCounter to (count (andSongName as text))
		
		if albumCounter < songNameCounter then
			set firstCounter to albumCounter
		else
			set firstCounter to songNameCounter
		end if
		
		repeat while firstCounter > 12
			set searchAlbum to text 1 thru firstCounter of (fromThisAlbum as text)
			set searchName to text 1 thru firstCounter of (andSongName as text)
			set firstCounter to firstCounter - 1
			
			if searchAlbum contains "_" then
				set searchAlbum to «class mRes» of («event SATIFINd» ".*(?=_)" with «class UsGR» given «class $in »:searchAlbum)
			end if
			
			try
				set allITunesTracks to (every «class cFlT» whose «class pTrN» is (withThisTrackNumber as number) and «class pAlb» contains searchAlbum and name contains searchName)
				if allITunesTracks is not {} then
					set foundMatch to true
					exit repeat
				end if
			end try
		end repeat
		
		if foundMatch is false then
			repeat while albumCounter > 14
				set searchAlbum to text 1 thru albumCounter of (fromThisAlbum as text)
				set albumCounter to albumCounter - 1
				
				if searchAlbum contains "_" then
					set searchAlbum to «class mRes» of («event SATIFINd» ".*(?=_)" with «class UsGR» given «class $in »:searchAlbum)
				end if
				
				try
					set allITunesTracks to (every «class cFlT» whose «class pTrN» is (withThisTrackNumber as number) and «class pAlb» contains searchAlbum and name contains andSongName)
					if allITunesTracks is not {} then
						set foundMatch to true
						exit repeat
					end if
				end try
			end repeat
		end if
		
		if foundMatch is false then
			repeat while songNameCounter > 14
				set searchName to text 1 thru songNameCounter of (andSongName as text)
				set songNameCounter to songNameCounter - 1
				
				try
					set allITunesTracks to (every «class cFlT» whose «class pTrN» is (withThisTrackNumber as number) and «class pAlb» contains fromThisAlbum and name contains searchName)
					if allITunesTracks is not {} then
						set foundMatch to true
						exit repeat
					end if
				end try
			end repeat
		end if
		
		if foundMatch is false then
			set lastResortCounter to 8
			repeat while lastResortCounter > 4
				set searchName to text 1 thru lastResortCounter of (andSongName as text)
				set searchAlbum to text 1 thru lastResortCounter of (fromThisAlbum as text)
				set lastResortCounter to lastResortCounter - 1
				
				try
					set allITunesTracks to (every «class cFlT» whose «class pTrN» is (withThisTrackNumber as number) and «class pAlb» contains searchAlbum and name contains searchName)
					if allITunesTracks is not {} then
						set foundMatch to true
						exit repeat
					end if
				end try
			end repeat
		end if
		
		if foundMatch is false then
			log ("Did not find " & andSongName & " as track " & withThisTrackNumber & " of " & fromThisAlbum)
		end if
		
		return allITunesTracks
	end tell
end findITunesTracksByFallback


on firstItemOrFallback(theList, fallbackValue)
	try
		if theList is not {} then return item 1 of theList
	on error
	end try
	return fallbackValue
end firstItemOrFallback
