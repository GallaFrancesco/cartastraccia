module cartastraccia.actor;

import cartastraccia.rss;

import vibe.core.log;
import vibe.inet.url;
import vibe.stream.operations : readAllUTF8;
import vibe.http.client;
import vibe.http.common;
import vibe.core.concurrency;
import vibe.core.core;
import pegged.grammar;
import sumtype;

import std.algorithm : each, filter;
import std.array;
import std.range;
import core.time;
import std.conv : to;
import std.variant;

alias RSSFeedList = SumType!(RSSFeed[], InvalidFeeds);

alias TaskMap = Task[string];

struct InvalidFeeds
{
	string msg;
}

struct RSSFeed
{
	string name;
	Duration refresh;
	string path;

	this(string[] props) @safe
	{
		name = props[0];
		path = props[3];

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

void updateFeed(immutable string path) @trusted
{
	RSS rss;
	URL url = URL(path);


	requestHTTP(url,
			(scope HTTPClientRequest req) {
				req.method = HTTPMethod.GET;
			},
			(scope HTTPClientResponse res) {
				parseRSS(rss, res.bodyReader.readAllUTF8());
			});

	while(true) {
		auto webTask = receiveOnly!Task;

		receive(
			(FeedActorRequest r) {
				if(r == FeedActorRequest.DATA) {
					logInfo("Received data request from task: "~webTask.getDebugID());
					RequestData data = dumpRSScli(rss);
					webTask.dispatch(data);
				} else if(r == FeedActorRequest.QUIT){
					logDebug("Task exiting");
					return;
				}},
			(Variant v) {
				logDebug("Invalid message received");
			});
	}
}

/**
 * Communication protocol between tasks
*/

enum FeedActorRequest { DATA, QUIT }

alias RequestData = string;
alias RequestDataLength = ulong;

static immutable ulong chunkSize = 4096;

void dispatch(scope Task task, immutable string data)
{
	ulong len = data.length;
	task.send(len);

	ulong a = 0;
	ulong b = chunkSize;
	while(a < len) {
		task.send(data[a..b]);
		a = b;
		b = (b+chunkSize > len) ? len : b + chunkSize;
	}
}
