# podcasting
Podcasting tools for generating and publishing podcast content.

# mixcloud2podcast

Some of my favorite music shows, like *Just a Blip* by my mate Glenn (links: [Feedburner](http://feeds.feedburner.com/just-a-blip) · [Mixcloud](https://www.mixcloud.com/DublinDigitalRadio/playlists/just-a-blip) · [DDR](https://listen.dublindigitalradio.com/resident/just-a-blip) · [Internet Archive](https://archive.org/details/@abmc?&and[]=subject%3A%22justablip%22) · [Apple Podcasts](https://podcasts.apple.com/us/podcast/just-a-blip/id1565531309)) are on Mixcloud, but I have been annoyed that I can only stream through Mixcloud's website or mobile app. I would prefer to listen on my podcast app of preference and download them so that I can still listen when I don't have a network connection. 

**mixcloud2podcast** is my answer to that annoyance. These (shell) scripts download all audio files for a Mixcloud playlist (or user) using **youtube-dl**, upload the audio files to the Internet Archive and generate an RSS podcast file which gets uploaded right here. It is now free from the walled garden of Mixcloud, and can be published to multiple podcast platforms allover the web.

### download.sh
1. Downloads all audio and json metadata for a mixcloud playlist or user  
2. Uploads audio to the internet archive (see upload.sh)  
3. Generates podcast rss file and pushes to this repo (see rss.sh)  
Requires a configuration file to be passed as argument.

### upload.sh
Uploads an audio file to the Internet Archive

### rss.sh
Creates a podcast rss file from a folder of audio and metadata json files downloaded from mixcloud using youtube-dl. Also pushes to a git repository.  
Heavily adapted from https://github.com/maxhebditch/rss-roller

### upload_batch.sh
Utility to batch upload multiple audio files to the Internet Archive

### publish.sh
Publishes (copies and git pushes) podcast website:
1. Rsyncs ../docs/podcast-name folder to a ../../podcast-name.github.io repo folder
2. git pushes to podcast-name.github.io repo (the actual live website)

_Main Requirements_:  

    brew install youtube-dl (to download files from mixcloud)  
    brew install ffmpeg  
    brew install internetarchive (Internet Archive's command line interface)  
    ia configure (configure ia with your credentials)  

# spotify2podcast

Likely the most convenient way to create a playlist is to use Spotify, but I have been annoyed that there is no way to record or export these playlists for offline listening. I would prefer to listen to playlists on my podcast app of preference, download them so that I can still listen when I don't have a network connection and listen without interruptions.

**spotify2podcast** is my answer to that annoyance. These (shell) scripts download all audio files for a Spotify playlist using **SpotDL**, upload the audio files to the Internet Archive and generate an RSS podcast file which gets uploaded right here. It is now free from the walled garden of Spotify, and can be published to multiple podcast platforms allover the web.

### download.sh
Generates a podcast mp3 episode from a Spotify playlist
1. Downloads all mp3s using Spotdl
2. Generates intro and outro mp3 files using text to speech service
3. Merges all mp3s in a m3u playlist to one big mp3
4. Adds id3 metadata to merged mp3 (ncluding chapters and cover)

### m3u2chapters.sh
Utility to generate ffmpeg chapter metadata file from an m3u playlist

### prepare.sh
Prepares a generated audio file episode to be uploaded:
1. Moves merged mp3 from download subdir to one dir up (if not already there)
2. Cleans up tmp files from download subdir
3. Generates json from merged mp3 and episode config file

### prepare_batch.sh
Utility to batch prepares multiple generated audio file episodes to be uploaded


**NOTE:** Shares **upload.sh**, **upload_batch.sh**, **rss.sh** and **prepare.sh** scripts (symlinked) with **mixcloud2podcast**.

_Main Requirements_:

    python3 -m pip install --user pipx && python3 -m pipx ensurepath
    brew install ffmpeg
    brew install mediainfo
    brew install internetarchive (Internet Archive's command line interface)
    ia configure (configure ia with your credentials)
    brew install imagemagick



