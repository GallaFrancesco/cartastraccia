 ▄████▄   ▄▄▄       ██▀███  ▄▄▄█████▓ ▄▄▄           ██████ ▄▄▄█████▓ ██▀███   ▄▄▄       ▄████▄   ▄████▄   ██▓ ▄▄▄      
▒██▀ ▀█  ▒████▄    ▓██ ▒ ██▒▓  ██▒ ▓▒▒████▄       ▒██    ▒ ▓  ██▒ ▓▒▓██ ▒ ██▒▒████▄    ▒██▀ ▀█  ▒██▀ ▀█  ▓██▒▒████▄    
▒▓█    ▄ ▒██  ▀█▄  ▓██ ░▄█ ▒▒ ▓██░ ▒░▒██  ▀█▄     ░ ▓██▄   ▒ ▓██░ ▒░▓██ ░▄█ ▒▒██  ▀█▄  ▒▓█    ▄ ▒▓█    ▄ ▒██▒▒██  ▀█▄  
▒▓▓▄ ▄██▒░██▄▄▄▄██ ▒██▀▀█▄  ░ ▓██▓ ░ ░██▄▄▄▄██      ▒   ██▒░ ▓██▓ ░ ▒██▀▀█▄  ░██▄▄▄▄██ ▒▓▓▄ ▄██▒▒▓▓▄ ▄██▒░██░░██▄▄▄▄██ 
▒ ▓███▀ ░ ▓█   ▓██▒░██▓ ▒██▒  ▒██▒ ░  ▓█   ▓██▒   ▒██████▒▒  ▒██▒ ░ ░██▓ ▒██▒ ▓█   ▓██▒▒ ▓███▀ ░▒ ▓███▀ ░░██░ ▓█   ▓██▒
░ ░▒ ▒  ░ ▒▒   ▓▒█░░ ▒▓ ░▒▓░  ▒ ░░    ▒▒   ▓▒█░   ▒ ▒▓▒ ▒ ░  ▒ ░░   ░ ▒▓ ░▒▓░ ▒▒   ▓▒█░░ ░▒ ▒  ░░ ░▒ ▒  ░░▓   ▒▒   ▓▒█░
  ░  ▒     ▒   ▒▒ ░  ░▒ ░ ▒░    ░      ▒   ▒▒ ░   ░ ░▒  ░ ░    ░      ░▒ ░ ▒░  ▒   ▒▒ ░  ░  ▒     ░  ▒    ▒ ░  ▒   ▒▒ ░
░          ░   ▒     ░░   ░   ░        ░   ▒      ░  ░  ░    ░        ░░   ░   ░   ▒   ░        ░         ▒ ░  ░   ▒   
░ ░            ░  ░   ░                    ░  ░         ░              ░           ░  ░░ ░      ░ ░       ░        ░  ░
░                                                                                      ░        ░                      

# Carta Straccia is a RSS feed aggregator

Written in D using [sumtype](https://code.dlang.org/packages/sumtype),
[pegged](https://code.dlang.org/packages/pegged),
[dxml](https://code.dlang.org/packages/dxml),
[htmld](https://code.dlang.org/packages/htmld) and [Vibe.d](https://vibed.org).

## Features

* Linux only (yep, it's a feature)
* Server/client architecture with simple CLI parameters
* Multi-tasking using Vibe.d's Tasks and the message passing model to
  concurrently process multiple feeds
* **Single-file feeds configuration**, with separate, per-feed refresh interval
* Multiple endpoints support: Display the aggregated news in HTML, from the
  command line (WIP) or edit `source/cartastraccia/endpoints.d` to add your
  desired visualization

## Installation

Requires [Dub](https://github.com/dlang/dub):

1. clone this repo:
```
git clone https://github.com/gallafrancesco/cartastraccia.git
```
2. build:
```
dub build
```

You'll find the `cartastraccia` executable in the root project directory.

## Usage

CLI options and sample first usage:
```
cartastraccia --help
```

For feeds configuration, see the sample `feeds.conf` file included.
