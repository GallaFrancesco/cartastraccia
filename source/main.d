/**
 * Copyright (c) 2019 Francesco Galla` - <me@fragal.eu>
 *
 * This file is part of cartastraccia.
 *
 * cartastraccia is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * cartastraccia is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with cartastraccia.  If not, see <https://www.gnu.org/licenses/>.
 * ---
 *
 * Main program launcher.
 *
*/

module main;

import cartastraccia.config;
import cartastraccia.asciiart;
import cartastraccia.actor;
import cartastraccia.endpoint;

import vibe.core.log;
import vibe.core.file;
import vibe.http.server;
import vibe.http.router;
import vibe.http.fileserver;
import vibe.inet.url;
import vibe.http.client;
import vibe.web.web;
import vibe.core.core;
import vibe.stream.operations : readAllUTF8;
import vibe.core.concurrency;
import pegged.grammar;
import sumtype;
import requests;

import std.exception;
import std.stdio;
import std.file : readText;
import std.algorithm : each;
import std.datetime : SysTime;
import std.getopt;
import std.conv : to;
import std.process;

immutable string info = "==========================================================================
|               Carta Straccia is a RSS feed aggregator                  |
==========================================================================
0. Write a feeds.conf file [feed_name refresh_timeout feed_url]
> echo \"Stallman 3h https://stallman.org/rss/rss.xml\" > feeds.conf
--------------------------------------------------------------------------
1. Start the daemon:
> cartastraccia --daemon --feeds=feeds.conf
--------------------------------------------------------------------------
2. Connect to daemon using HTML endpoint
> cartastraccia --browser=/path/to/browser
==========================================================================";

/**
 * Start a vibe.d webserver
 * using an already initialied router
 * Loops on the eventloop until stopped.
 */
void runWebServer(ref URLRouter router, immutable string bindAddress, immutable ushort bindPort)
{
	auto settings = new HTTPServerSettings;
	settings.port = bindPort;
	settings.bindAddresses = ["127.0.0.1", bindAddress];

	listenHTTP(settings, router);
	runEventLoop();
}

/**
 * This function is in charge of:
 * - reading `feeds.conf`
 * - initializing an actor for each RSS feed, with early return in case of failure
 * - registering a vibe.d router with an handle for each endpoint [html, cli, json, ...]
 * - starting a webserver
 */
void runDaemon(immutable string feedsFile, immutable
		string bindAddress, immutable ushort bindPort)
{

	auto feeds = loadFeedsConfig(feedsFile);
	TaskMap tasks;

	feeds.match!(
			(InvalidFeeds i) {
				logWarn("Invalid feeds processed. Exiting.");
				return;
			},
			(RSSActor[] fl) {

				// n. threads == n. feeds
				setupWorkerThreads(fl.length.to!uint);

				// start tasks in charge of updating feeds
				feeds.match!(
						(InvalidFeeds i) => logFatal(i.msg),
						(RSSActor[] fl) {
							fl.each!(
									(RSSActor feed) {
										logInfo("Starting task: "~feed.name);
										// start workers to serve RSS data
										tasks[feed.name] = runWorkerTaskH(
												&feedActor, feed.name, feed.path, 0);
									});
						});

				// initialize a new service to serve requests
				auto router = new URLRouter;
				router.registerWebInterface(new EndpointService(feeds, tasks,
							feedsFile));
				router.get("*", serveStaticFiles("public/"));

				// start the webserver in main thread
				runWebServer(router, bindAddress, bindPort);
		});
}

void runClient(EndpointType endpoint, immutable string browser, immutable string
		bindAddress, immutable ushort bindPort, immutable bool reloadFeeds)
{

	import std.stdio;

	if(reloadFeeds) {
		try {
			string url = "http://"~bindAddress~":"~bindPort.to!string~"/reload";
			auto req = Request();
			req.keepAlive = false;
			req.timeout = ACTOR_REQ_TIMEOUT;
			req.get(url);

		} catch (Exception e) {
			logWarn("ERROR from daemon: "~e.msg~"\nCannot reload feeds file.");
		}
	}

	if(endpoint == EndpointType.cli) {
		try {
			string url = "http://"~bindAddress~":"~bindPort.to!string~"/cli";
			auto req = Request();
			req.keepAlive = false;
			req.timeout = ACTOR_REQ_TIMEOUT;
			req.get(url);

		} catch (Exception e) {
			logWarn("ERROR from daemon: "~e.msg~"\nCheck daemon logs for details (is it running?)");
		}

	} else if(endpoint == EndpointType.html) {

		if(!existsFile(browser)) {
			logWarn("Could not find browser: "~browser);
			logWarn("Try running: cartastraccia --browser=[/path/to/browser]");
			return;
		}

		immutable address = "http://"~bindAddress~":"~bindPort.to!string;
		auto pid = spawnShell(browser ~" "~address);
		wait(pid);
	}
}

void main(string[] args)
{
	// CLI arguments
	bool daemon = false;
	EndpointType endpoint = EndpointType.html;
	string feedsFile = "feeds.conf";
	string bindAddress = "localhost";
	ushort bindPort = 8080;
	string browser = "/usr/bin/elinks";
	bool reloadFeeds = false;

	auto helpInformation = getopt(
			args,
			"daemon|d", "Start daemon", &daemon,
			"endpoint|e", "Endpoints to register [cli]", &endpoint,
			"feeds|f", "File containing feeds to pull [feeds.conf]", &feedsFile,
			"host|l", "Bind to this address [localhost]", &bindAddress,
			"port|p", "Bind to this port [8080]", &bindPort,
			"browser|b", "Absolute path to browser for HTML rendering [/usr/bin/elinks]", &browser,
			"reload|r", "Reload feeds file", &reloadFeeds
		);

	if(helpInformation.helpWanted) {
		defaultGetoptPrinter(info, helpInformation.options);
		return;
	}

	if(daemon && reloadFeeds) {
		logWarn("Starting daemon. Feeds file loading is the default behavior. Ignoring reload request.");
	}

	if(daemon) runDaemon(feedsFile, bindAddress, bindPort);
	else runClient(endpoint, browser, bindAddress, bindPort, reloadFeeds);
}
