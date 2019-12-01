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
 * Pluggable endpoint interface using Vibe.d services.
 *
*/

module cartastraccia.endpoint;

import cartastraccia.config;
import cartastraccia.asciiart;
import cartastraccia.actor;
import cartastraccia.rss;

import vibe.core.core;
import vibe.core.log;
import vibe.core.task;
import vibe.core.concurrency;
import vibe.http.router;
import vibe.web.web;
import sumtype;

import std.algorithm : each, filter;
import std.datetime;
import core.time;

enum EndpointType {
	cli,
	html
}

/**
 * Implementing methods for a vibe Web Interface.
 * Functions are mapped to a URL path via an attribute.
 *
 * For more informations see:
 * vibed.org/api/vibe.web.web/registerWebInterface
 */
class EndpointService {

	private {
		RSSActorList feedList;
		TaskMap tasks;
		immutable string configFile;
	}

	DateTime[string] lastUpdate;

	this(RSSActorList fl, TaskMap tm, immutable string config)
	{
		feedList = fl;
		tasks = tm;
		configFile = config;

		// refresh RSS data with a timer
		feedList.tryMatch!((RSSActor[] fl) {

				fl.each!((RSSActor feed) {

					lastUpdate[feed.name] = cast(DateTime)Clock.currTime();

					setTimer(feed.refresh, () {

							if(feed.name in tasks)
								tasks[feed.name].send(Task.getThis());
							else return;

							auto resp = receiveOnly!FeedActorResponse;
							if(resp == FeedActorResponse.INVALID) {
								return;
							}

							// set last update time
							lastUpdate[feed.name] = cast(DateTime)Clock.currTime();

							tasks[feed.name].send(FeedActorRequest.QUIT);
							tasks[feed.name] = runWorkerTaskH(&feedActor, feed.name, feed.path, 0);

							logInfo("["~feed.name~"] Finished updating.");

							}, true);
				});
		});
	}

    /**
     * Called when an http request is made to "<bindaddress>:<bindport>/reload"
     * Requests the rss feeds from their respective hosts.
     */
	void getReload(scope HTTPServerRequest req, scope HTTPServerResponse res)
	{
		logInfo("Received reload request. Stopping current tasks.");

		feedList.match!(
			(InvalidFeeds i) {},
			(RSSActor[] fl) {
				fl.each!(
					(RSSActor f) {

						actorHandshake(f.name);

						tasks[f.name].send(FeedActorRequest.QUIT);
					});
				});

		loadFeedsConfig(configFile).match!(

				(InvalidFeeds i) {
					logWarn("Not reloading");
				},
				(RSSActor[] feeds) {
					logInfo("Successfully reloaded feeds file.");
					feedList = feeds;
				});

		tasks = resumeWorkers(feedList, tasks);
		res.writeBody("Successfully reloaded feeds file.");
	}

    /**
     * Called when an http request is made to "<bindaddress>:<bindport>/". 
     * Returns the index file in html form.
     */
    @path("/") void getHTMLEndpoint(scope HTTPServerRequest req, scope HTTPServerResponse res)
	{
		RSSActor[] validFeeds;
		feedList.match!(

				(InvalidFeeds i) {},

				(RSSActor[] fl) {

					fl.filter!((RSSActor f) => f.name in tasks)
						.each!((RSSActor f) {

							if(!actorHandshake(f.name)) return;

							// send data request
							tasks[f.name].send(FeedActorRequest.DATA_HTML);

							// add valid feed to list
							validFeeds ~= f;
						});

					feedList = validFeeds;
					res.render!("index.dt", req, validFeeds, lastUpdate, asciiArt);
				});
	}

    /**
     * Called when an http request is made to "<bindaddress>:<bindport>/cli". 
     * Returns data gathered from the RSS feeds in a weakly formatted form.
     */
	@path("/cli") void getCLIEndpoint(scope HTTPServerResponse res)
	{
		string data;
		feedList.match!(
				(InvalidFeeds i) {},
				(RSSActor[] fl) {
					fl.each!(
						(RSSActor f) {

							if(!actorHandshake(f.name)) return;

							// send data request
							tasks[f.name].send(FeedActorRequest.DATA_CLI);
							// receive data length
							auto totSize = receiveOnly!RequestDataLength;

							RequestDataLength recSize = 0;

							while(recSize < totSize) {
								data ~= receiveOnly!string;
								recSize += chunkSize;
							}

							data ~= "End of feed: " ~ f.name ~ "\n";

						});
				});

		res.writeBody(data);
	}
private:

	bool actorHandshake(immutable string fname)
	{
		// send task for response from server
		if(!(fname in tasks)) return false;

		tasks[fname].send(Task.getThis());

		auto resp = receiveOnly!FeedActorResponse;

		if(resp == FeedActorResponse.INVALID) {
			return false;
		}

		return true;
	}
}


