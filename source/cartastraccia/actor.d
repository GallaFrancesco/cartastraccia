module cartastraccia.actor;

import cartastraccia.rss;
import cartastraccia.renderer;

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
				busyListen(feedName, rss);
			},
			(ref ValidRSS vr) {
				immutable fileName = "public/channels/"~feedName~".html";
				createHTMLPage(vr, feedName, fileName);
				busyListen(feedName, rss);
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
void busyListen(immutable string feedName, ref RSS rss) {
	rss.match!(
			(ref InvalidRSS i) {
					auto webTask = receiveOnly!Task;
					webTask.send(FeedActorResponse.INVALID);
				},
			(ref ValidRSS vr) {
				while(true) {

					try {
						// receive the webserver task
						Task webTask = receiveOnly!Task;

						if(webTask.running)	webTask.send(FeedActorResponse.VALID);
						else {
							logWarn("Web task is not running");
							return;
						}

						// receive the actual request
						receive(
							(FeedActorRequest r) {
								switch(r) {

								case FeedActorRequest.DATA_CLI:
									logInfo("Received CLI request from task: "~webTask.getDebugID());
									immutable string data = dumpRSS!(FeedActorRequest.DATA_CLI)(vr);
									webTask.dispatchCLI(data);
									break;

								case FeedActorRequest.DATA_HTML:
									logInfo("Received HTML request on feed: "~feedName~"[Task: "~webTask.getDebugID()~"]");
									break;

								case FeedActorRequest.QUIT:
									logInfo("Task exiting due to QUIT request.");
									return;

								default:
									logFatal("Task received unknown request.");
								}
							},

							(Variant v) {
								logFatal("Invalid message received from webserver.");
							});

					} catch (Exception e) {
						logWarn("Waiting for actors to complete loading feeds.");
					}
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
