# podcasting
Podcasting tools for generating and publishing podcast content.

## mixcloud2podcast:

Some of my favorite music shows, like *Just a Blip* by my mate Glenn (links: [Feedburner](http://feeds.feedburner.com/just-a-blip) · [Mixcloud](https://www.mixcloud.com/DublinDigitalRadio/playlists/just-a-blip) · [DDR](https://listen.dublindigitalradio.com/resident/just-a-blip) · [Internet Archive](https://archive.org/details/@abmc?&and[]=subject%3A%22justablip%22) · [Apple Podcasts](https://podcasts.apple.com/us/podcast/just-a-blip/id1565531309)) are on Mixcloud, but I have been annoyed that I can only stream through Mixcloud's website or mobile app. I would prefer to listen on my podcast app of preference and download them so that I can still listen when I don't have a network connection. 

mixcloud2podcast is my answer to that annoyance. These (shell) scripts download all audio files for Mixcloud playlist (or user) using youtube-dl, upload the audio files to the Internet Archive and generate an RSS podcast file which gets uploaded right here. It is now free from the walled garden of Mixcloud, and is published to multiple podcast platforms allover the web.

#### download.sh
Downloads all m4a and json metadata for a mixcloud playlist or user
1. Downloads all m4a and json metadata for a mixcloud playlist or user
2. uploads mp4a to the internet archive 
3. Generates podcast rss file

#### upload.sh
Uploads a mixcloud .m4a file to the Internet Archive

#### rss.sh
Creates a podcast rss file from a folder of m4a and metadata json files downloaded from mixcloud using youtube-dl. Also pushes to a git repository.

Heavily adapted from https://github.com/maxhebditch/rss-roller

#### upload_batch.sh
Utility to batch upload multiple mixcloud .m4a files to the Internet Archive

_Requirements_:
brew install youtube-dl (to download files from mixcloud)
brew install ffmpeg
brew install internetarchive (Internet Archive's command line interface)
ia configure (configure ia with your credentials)
