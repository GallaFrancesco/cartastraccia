module cartastraccia.actor;

import cartastraccia.rss;

import vibe.core.log;
import vibe.inet.url;
import vibe.stream.operations : readAllUTF8;
import vibe.http.client;
import vibe.http.common;
import pegged.grammar;
import sumtype;

import std.algorithm : each, filter;
import std.array;
import std.range;
import std.stdio;
import core.time;
import std.conv : to;

alias RSSFeedList = SumType!(RSSFeed[], InvalidFeeds);

struct InvalidFeeds
{
	string msg;
}

struct RSSFeed
{
	string name;
	Duration refresh;
	URL url;

	this(string[] props) @safe
	{
		name = props[0];
		url = URL(props[3]);

		switch(props[2][0]) {
			case 's':
				refresh = dur!"seconds"(props[1].to!uint);
				break;
			case 'm':
				refresh = dur!"minutes"(props[1].to!uint);
				break;
			case 'h':
				refresh = dur!"hours"(props[1].to!uint);
				break;
			case 'd':
				refresh = dur!"days"(props[1].to!uint);
				break;
			default:
				assert(false, "should not get here");
		}
	}

}

RSSFeedList processFeeds(ParseTree pt) @trusted
{
	RSSFeed[] feeds;

	foreach(ref conf; pt.children) {
		foreach(ref feed; conf.children) {
			feeds ~= RSSFeed(feed.matches
						.filter!((immutable s) => s != "\n" && s != " ")
						.array
					);
		}
	}
	if(feeds.empty) return RSSFeedList(InvalidFeeds("No feeds found"));
	else return RSSFeedList(feeds);
}

auto updateFeed(immutable URL url) @safe
{
	RSS rss;

	requestHTTP(url,
			(scope HTTPClientRequest req) {
				req.method = HTTPMethod.GET;
			},
			(scope HTTPClientResponse res) {
				rss = res.bodyReader.readAllUTF8.parseRSS;
			});

}
