module app;

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

immutable string info = "
=============================================
|  Carta Straccia is a RSS feed aggregator  |
=============================================
0. Write a feeds.conf file [feed_name refresh_timeout feed_url]
> echo \"Stallman 3h https://stallman.org/rss/rss.xml\" > feeds.conf
---------------------------------------------
1. Start the daemon:
> cartastraccia --daemon --endpoint=cli --endpoint=html --feeds=feeds.conf
---------------------------------------------
2. Connect to daemon using HTML endpoint
> cartastraccia --browser=/path/to/browser
---------------------------------------------";

void runWebServer(ref URLRouter router, immutable string bindAddress, immutable ushort bindPort)
{
	auto settings = new HTTPServerSettings;
	settings.port = bindPort;
	settings.bindAddresses = ["127.0.0.1", bindAddress];

	listenHTTP(settings, router);
	runEventLoop();
}

void runDaemon(immutable string feedsFile, immutable
		string bindAddress, immutable ushort bindPort)
{
	// parse feed list
	auto pt = ConfigFile(readText(feedsFile));
	enforce(pt.successful, "Invalid "~feedsFile~" file format, check cartastraccia.config for grammar");
	auto feeds = processFeeds(pt);
	TaskMap tasks;

	feeds.match!(
			(InvalidFeeds i) {
				logWarn("Invalid feeds processed. Exiting.");
				return;
			},
			(RSSFeed[] fl) {

				// n. threads == n. feeds
				setupWorkerThreads(fl.length.to!uint);

				// start tasks in charge of updating feeds
				feeds.match!(
						(InvalidFeeds i) => logFatal(i.msg),
						(RSSFeed[] fl) {
							fl.each!(
									(RSSFeed feed) {
										logInfo("Starting task: "~feed.name);
										// start workers to serve RSS data
										tasks[feed.name] = runWorkerTaskH(
												&feedActor, feed.name, feed.path, 0);
									});
						});

				// initialize a new service to serve requests
				auto router = new URLRouter;
				router.registerWebInterface(new EndpointService(feeds, tasks));
				router.get("*", serveStaticFiles("public/"));

				// start the webserver in main thread
				runWebServer(router, bindAddress, bindPort);
		});
}

void runClient(EndpointType endpoint, immutable string browser, immutable string
		bindAddress, immutable ushort bindPort, immutable bool reloadFeeds)
{

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

	if(daemon) runDaemon(feedsFile, bindAddress, bindPort);
	else runClient(endpoint, browser, bindAddress, bindPort, reloadFeeds);
}
