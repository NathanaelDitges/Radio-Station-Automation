# Audio Workflow AppleScripts for macOS

A set of AppleScripts for batch audio conversion, song classification, playlist creation, MP3 discovery, and library organization on macOS.

These scripts were developed as workflow utilities for processing and organizing music files. They were made for dealing with massive music libraries in a radio station. 

## Purpose

These scripts handled the workflow of:

- finding a Music CD or file directory of an assorted music file types, 
- converting all music to MP3, 
- categorizing the music by form, genre, production quality,
- renaming the music for the Brodcasting software use, 
- logging the music into a XML music list compatable with CDpedia.


## Included Scripts

- `batch-audio-to-mp3.scpt` — Batch converts selected audio files to MP3.
- `batch-convert-wav-m4a-wma-to-mp3.scpt` — Recursively finds and converts WAV, M4A, and WMA files to MP3.
- `classify-songs-into-music-playlists.scpt` — Manually reviews songs and adds them to Music playlists based on user classification.
- `convert-audio-to-external-SSD-mp3-folder.scpt` — Converts supported audio files to MP3 and writes them to a fixed external SSD location.
- `convert-selected-audio-to-mp3.scpt` — Converts selected Finder audio files to MP3.
- `convert-wav-and-build-music-playlists.scpt` — Converts WAV files and organizes them into Music playlists based on folder names.
- `find-and-select-mp3-files.scpt` — Recursively scans Finder selections and selects all MP3 files found.
- `sort-songs-by-xml-and-create-aliases.scpt` — Uses filename, metadata, and XML-based track data to sort songs and create alias-based artist/album folders.

## Environment

Most scripts were made with:

- A configured Conda environment named `Music-env`
- Sound Studio Software
- CDpedia Sofware
- `ffmpeg`, `sox`, and `vlc`

Some scripts also rely on custom XML and regex AppleScript additions or Script Debugger terminology.

## Important Notes

These scripts were written for a personal music-management workflow and may require edits before use on another machine.

In particular:

- hard-coded file paths may need to be changed
- external drive names may need to be updated
- some scripts assume specific filename formats
- some workflows move or delete original files

## Safety

Please test on duplicate files before using these scripts on an active music library.
