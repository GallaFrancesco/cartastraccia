# Carta Straccia is a RSS feed aggregator

Written in D using [sumtype](https://code.dlang.org/packages/sumtype),
[pegged](https://code.dlang.org/packages/pegged),
[htmld](https://code.dlang.org/packages/htmld),
[requests](https://code.dlang.org/requests) and [Vibe.d](https://vibed.org)

RSS parsing uses
[libmrss](https://autistici.org/bakunin/libmrss/doc/index.html).

## Features

* Linux only (yep, it's a feature)
* Server/client architecture with simple CLI parameters
* Multi-tasking using Vibe.d's Tasks and the message passing model to
  concurrently process multiple feeds
* **Single-file feeds configuration**, with separate, per-feed refresh interval
* Multiple endpoints support: Display the aggregated news in HTML, from the
  command line (WIP) or edit `source/cartastraccia/endpoints.d` to add your
  desired visualization
* HTML endpoint visualization can be customized editing `public/css/*` and the
  frontpage's Diet Template in `views/index.dt`
* RSS parsing and partial validation (WIP) by keeping the tags needed to a
  minimum: Carta Straccia follows a text-preferred phylosophy and tries to push
  any other information out of the way by omitting it when possible.

## Installation

This program is compatible with a Unix-like OS, notably GNU/Linux. Other
platforms (OSX, Windows) are not supported and they probably won't ever be.

### Dependencies

Carta Straccia uses
[libmrss](https://autistici.org/bakunin/libmrss/doc/index.html) to parse RSS
feeds. It can be installed in the following ways:

* **Using your package manager**: `libmrss` can be installed from the main
	repositories of some distros, using the appropriate package manager. Examples:
		- Gentoo/portage: `emerge libmrss`
		- Debian/apt and derivatives: `apt install libmrss`
		- etc.


* **From source**: If `libmrss` is not available for your distribution,
it can be built and installed from source. See:
[https://github.com/bakulf/libmrss](https://github.com/bakulf/libmrss).

### Building

Requires a working D compiler and [Dub](https://github.com/dlang/dub):

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

## License

This project is licensed under the terms of the GPLv3 License.

## Contributing

Feel free to open issues and PRs. Current TODOs are:

* Work on a comfortable and polished CLI endpoint
* Add enpoints in general (new visualization, curses, improve HTML...)
* Implement an efficient categorization of feeds (by topic maybe?)
* Oneshot mode (no daemon, cron support), might be connected to local archive
  for article (DB/text)?
* Documentation and usage examples.
