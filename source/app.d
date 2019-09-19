module app;

import cartastraccia.config;
import cartastraccia.actor;
import cartastraccia.endpoint;

import vibe.core.log;
import vibe.http.server;
import vibe.http.router;
import vibe.inet.url;
import vibe.http.client;
import vibe.web.web;
import vibe.core.core;
import vibe.stream.operations : readAllUTF8;
import vibe.core.concurrency;
import pegged.grammar;
import sumtype;

import std.exception;
import std.stdio;
import std.file : readText;
import std.algorithm : each;
import std.getopt;
import std.conv : to;

immutable string info = "=============================================
CARTASTRACCIA is a news reader for RSS feeds.
=============================================
0. Write a feeds.conf file [feed_name refresh_timeout feed_url]
> echo \"Stallman 3h https://stallman.org/rss/rss.xml\" > feeds.conf
---------------------------------------------
1. Start the daemon:
> cartastraccia --daemon --endpoint=cli --endpoint=html --feeds=feeds.conf
---------------------------------------------
2a. Connect to daemon using CLI endpoint:
> cartastraccia
---------------------------------------------
2b. Connect to daemon using HTML endpoint:
> elinks \"http://localhost:8080\"
---------------------------------------------";

void runWebServer(ref URLRouter router, immutable string bindAddress, immutable ushort bindPort)
{
	auto settings = new HTTPServerSettings;
	settings.port = bindPort;
	settings.bindAddresses = ["127.0.0.1", bindAddress];

	listenHTTP(settings, router);
	runEventLoop();
}

void runDaemon(EndpointType[] endpoints, immutable string feedsFile, immutable
		string bindAddress, immutable ushort bindPort)
{
	// parse feed list
	auto pt = ConfigFile(readText(feedsFile));
	assert(pt.successful, "Invalid "~feedsFile~" file format, check cartastraccia.config for grammar");
	auto feeds = processFeeds(pt);
	TaskMap tasks;

	// start tasks in charge of updating feeds
	feeds.match!(
			(InvalidFeeds i) => logFatal(i.msg),
			(RSSFeed[] fl) {
				fl.each!(
						(RSSFeed feed) {
							tasks[feed.name] = runWorkerTaskH(&feedActor, feed.name, feed.path);
						});
			});

	// initialize a new service to serve endpoints
	auto router = new URLRouter;
	router.registerWebInterface(new EndpointService(feeds, tasks));

	// start the webserver in main thread
	runWebServer(router, bindAddress, bindPort);
}

void runClient(immutable string bindAddress, immutable ushort bindPort)
{
	URL url = URL("http://"~bindAddress~":"~bindPort.to!string~"/cli");
	try {
		requestHTTP(url,
			(scope HTTPClientRequest req) {
				req.method = HTTPMethod.GET;
			},
			(scope HTTPClientResponse res) {
					writeln(res.bodyReader.readAllUTF8());
			});
	} catch (Exception e) {
		logWarn("ERROR from daemon: "~e.msg~"\nCheck daemon logs for details (is it running?)");
	}
}

void main(string[] args)
{
	// CLI arguments
	bool daemon = false;
	EndpointType[] endpoints = [EndpointType.cli];
	string feedsFile = "feeds.conf";
	string bindAddress = "localhost";
	ushort bindPort = 8080;

	auto helpInformation = getopt(
			args,
			"daemon|d", "Start daemon", &daemon,
			"endpoint|e", "Endpoints to register [cli]", &endpoints,
			"feeds|f", "File containing feeds to pull [feeds.conf]", &feedsFile,
			"host|l", "Bind to this address [localhost]", &bindAddress,
			"port|p", "Bind to this port [8080]", &bindPort
		);

	if(helpInformation.helpWanted) {
		defaultGetoptPrinter(info, helpInformation.options);
		return;
	}

	if(daemon) runDaemon(endpoints, feedsFile, bindAddress, bindPort);
	else runClient(bindAddress, bindPort);
}
