module app;

import cartastraccia.rss;
import cartastraccia.config;
import cartastraccia.actor;

import vibe.core.log;
import pegged.grammar;

import std.stdio;
import std.file : readText;

static immutable string feedsFile = "feeds.conf";

void main()
{
	// parse feed list
	auto pt = ConfigFile(readText(feedsFile));
	assert(pt.successful, "Invalid "~feedsFile~" file format, check cartastraccia.config for grammar");
	processFeeds(pt);

	// parse every feed, update if needed
	//parseRSS(readText("example.xml"));
}
