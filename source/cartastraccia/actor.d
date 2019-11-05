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
 * Feed actor logic and inter-actor communication primitives.
 *
*/

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
import requests;

import std.algorithm : each, filter;
import std.array;
import std.range;
import core.time;
import std.conv : to;
import std.variant;
import std.string : assumeUTF;
import std.utf : validate;

alias TaskMap = Task[string];

immutable uint ACTOR_MAX_RETRIES = 3;
immutable ACTOR_REQ_TIMEOUT = 5.seconds;


/**
 * Main RSS Actor data
*/
alias RSSActorList = SumType!(RSSActor[], InvalidFeeds);

/**
 * Used when an error 
 * in the configuration file is encountered
 */
struct InvalidFeeds
{
	string msg;
}

/**
 * Generated from each line of the configuration file,
 * the members describes entries by the user.
 */
struct RSSActor
{
    /// title of the feed
	string name;
    /// refresh rate, seconds/minutes/hours/days
	Duration refresh;
    /// URL to request the rss feed
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

RSSActorList processFeeds(ParseTree pt) @trusted
{
	RSSActor[] feeds;

	foreach(ref conf; pt.children) {
		foreach(ref feed; conf.children) {
			feeds ~= RSSActor(feed.matches
						.filter!((immutable s) => s != "\n" && s != " ")
						.array
					);
		}
	}
	if(feeds.empty) return RSSActorList(InvalidFeeds("No feeds found"));
	else return RSSActorList(feeds);
}

/**
 * Requests and parse a RSS feed from a remote host.
 * In case of success create an html page into:
 * "public/channels/<feedName>.html";
 * Function executed in a task.
 */
void feedActor(immutable string feedName, immutable string path, immutable uint retries) @trusted
{
	RSS rss;
	URL url = URL(path);

	try {
		auto req = Request();
		req.keepAlive = false;
		req.timeout = ACTOR_REQ_TIMEOUT;
		auto res = req.get(path);
		string tmp = res.responseBody.data.assumeUTF;
		validate(tmp);
		parseRSS(rss, tmp);

	} catch (Exception e) {

		if(retries < ACTOR_MAX_RETRIES) {
	 		feedActor(feedName, path, retries+1); // retry by recurring
			return;
		}
		rss = FailedRSS(e.msg);
	}

	rss.match!(
			(ref InvalidRSS i) {
				logWarn("Invalid feed at: "~path);
				logWarn("Caused by: \""~i.element~"\": "~i.content);
			},
			(ref FailedRSS f) {
				logWarn("Failed to load feed: "~ feedName);
				logWarn("Error: "~f.msg);
			},
			(ref ValidRSS vr) {
				immutable fileName = "public/channels/"~feedName~".html";
				createHTMLPage(vr, feedName, fileName);
			});

	listenOnce(feedName, rss);
}

/**
 * Resurrect a set of tasks by updating the associated data structs
*/
TaskMap resumeWorkers(RSSActorList feeds, TaskMap oldTasks)
{
	TaskMap tasks;

	feeds.match!(
			(InvalidFeeds i) {
				logWarn("Invalid feeds processed. Exiting.");
				return;
			},
			(RSSActor[] fl) {

				// start tasks in charge of updating feeds
				feeds.match!(
						(InvalidFeeds i) => logFatal(i.msg),
						(RSSActor[] fl) {
							fl.each!(
									(RSSActor feed) {
										logInfo("Starting task: "~feed.name);

										// ensure all previous tasks are destroyed
										if(oldTasks[feed.name].running()) {
											logWarn("["~feed.name~"] Force stop.");
											oldTasks[feed.name].interrupt();
										}

										// start new workers
										tasks[feed.name] = runWorkerTaskH(
												&feedActor, feed.name, feed.path, 0);
									});
						});
			});
	return tasks;
}

/**
 * Communication protocol between tasks
*/
enum FeedActorRequest { DATA_CLI, DATA_HTML, QUIT }

/// ditto
enum FeedActorResponse { INVALID, VALID }

alias RequestDataLength = ulong;

static immutable ulong chunkSize = 4096;

private:

/**
 * Listen for messages from the webserver
 */
void listenOnce(immutable string feedName, ref RSS rss) {

	bool quit = false;

	rss.match!(
			(ref InvalidRSS i) {
					auto webTask = receiveOnly!Task;
					webTask.send(FeedActorResponse.INVALID);
					quit = true;
				},

			(ref FailedRSS f) {
					auto webTask = receiveOnly!Task;
					webTask.send(FeedActorResponse.INVALID);
					quit = true;
				},

			(ref ValidRSS vr) {
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
									logInfo("["~feedName~"] Task exiting due to QUIT request.");
									quit = true;
									break;

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

			});

	if(quit) return;
	else listenOnce(feedName, rss);
}

/**
 * Debug only
*/
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

