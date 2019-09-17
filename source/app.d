module app;

import cartastraccia.rss;
import cartastraccia.config;
import cartastraccia.actor;

import vibe.core.log;
import vibe.http.server;
import vibe.core.core;
import pegged.grammar;
import sumtype;

import std.stdio;
import std.file : readText;
import std.algorithm : each;

static immutable string feedsFile = "feeds.conf";

void handleReq(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe
{
	logInfo("Received request");
}

void main()
{
	// parse feed list
	auto pt = ConfigFile(readText(feedsFile));
	assert(pt.successful, "Invalid "~feedsFile~" file format, check cartastraccia.config for grammar");
	auto feeds = processFeeds(pt);

	// start tasks in charge of updating feeds
	feeds.match!(
			(InvalidFeeds i) => logFatal(i.msg),
			(RSSFeed[] fl) {
				fl.each!(
						(RSSFeed feed) {
							runTask(&updateFeed, feed.url);
						});
			});

	auto settings = HTTPServerSettings();
    settings.port = 8080;
    settings.bindAddresses = ["127.0.0.1"];
    listenHTTP!handleReq(settings);

	runApplication;
}
