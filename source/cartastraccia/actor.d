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

alias TaskMap = Task[string];

/**
 * Actor in charge of:
 * - parsing a RSS feed
 * - dumping news to DB
 * - listening for messages from the webserver
*/
void feedActor(immutable string feedName, immutable string path) @trusted
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

	rss.match!(
			(ref InvalidRSS i) {
				logWarn("Invalid feed at: "~path);
				logWarn("Caused by entry \""~i.element~"\": "~i.content);
				busyListen(rss);
			},
			(ref ValidRSS vr) {
				busyListen(rss);
			});
}

/**
 * Communication protocol between tasks
*/
enum FeedActorRequest { DATA_CLI, DATA_HTML, QUIT }

enum FeedActorResponse { INVALID, VALID }

alias RequestDataLength = ulong;


static immutable ulong chunkSize = 4096;

private:

/**
 * Listen for messages from the webserver
*/
void busyListen(ref RSS rss) {
	rss.match!(
			(ref InvalidRSS i) {
					auto webTask = receiveOnly!Task;
					webTask.send(FeedActorResponse.INVALID);
				},
			(ref ValidRSS vr) {
				while(true) {

					// receive the webserver task
					auto webTask = receiveOnly!Task;
					webTask.send(FeedActorResponse.VALID);

					// receive the actual request
					receive(
						(FeedActorRequest r) {


							if(r == FeedActorRequest.DATA_CLI) {
								logInfo("Received CLI request from task: "~webTask.getDebugID());
								immutable string data = dumpRSS!(FeedActorRequest.DATA_CLI)(vr);
								webTask.dispatchCLI(data);

							} else if(r == FeedActorRequest.DATA_HTML) {
								logInfo("Received HTML request from task: "~webTask.getDebugID());
								webTask.dispatchHTML(vr.channels);

							} else if(r == FeedActorRequest.QUIT){
								logDebug("Task exiting due to quit request.");
								return;

							}},

						(Variant v) {
							logFatal("Invalid message received from webserver.");
						});
				}
			});
}

void dispatchCLI(scope Task task, immutable string data)
{
	ulong len = data.length;
	task.send(len);

	ulong a = 0;
	ulong b = (chunkSize > len) ? len : chunkSize;
	while(a < len) {
		task.send(data[a..b]);
		a = b;
		b = (b+chunkSize > len) ? len : b + chunkSize;
	}
}

void dispatchHTML(scope Task task, RSSChannel[string] channels)
{
	ulong len = channels.length;
	task.send(len);

	foreach(string cname, RSSChannel ch; channels) {
		task.send(cname);
		ulong ilen = ch.items.length;
		task.send(ilen);
		foreach(string iname, RSSItem item; ch.items) {
			task.send(item);
		}
	}
}

