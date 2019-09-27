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

import std.algorithm : each;
import std.datetime;
import core.time;

enum EndpointType {
	cli,
	xml,
	html
}

class EndpointService {

	private {
		RSSFeedList feedList;
		TaskMap tasks;
	}

	DateTime[string] lastUpdate;

	this(RSSFeedList fl, TaskMap tm)
	{
		feedList = fl;
		tasks = tm;

		// refresh RSS data with a timer
		feedList.tryMatch!((RSSFeed[] fl) {

				fl.each!((RSSFeed feed) {

					lastUpdate[feed.name] = cast(DateTime)Clock.currTime();

					setTimer(feed.refresh, () {

							if(feed.name in tasks)
								tasks[feed.name].send(Task.getThis());
							else return;

							auto resp = receiveOnly!FeedActorResponse;
							if(resp == FeedActorResponse.INVALID) {
								tasks.remove(feed.name);
								return;
							}

							// set last update time
							lastUpdate[feed.name] = cast(DateTime)Clock.currTime();

							tasks[feed.name].send(FeedActorRequest.QUIT);
							tasks[feed.name] = runWorkerTaskH(&feedActor, feed.name, feed.path, 0);

							logInfo("Finished updating: " ~ feed.name);

							}, true);
				});
		});
	}

	@path("/") void getHTMLEndpoint(scope HTTPServerRequest req, scope HTTPServerResponse res)
	{
		RSSFeed[] validFeeds;
		feedList.match!(

				(InvalidFeeds i) {},

				(RSSFeed[] fl) {

					fl.each!((RSSFeed f) {

							// send task for response from server
							if(f.name in tasks) tasks[f.name].send(Task.getThis());
							else {
								tasks.remove(f.name);
								return;
							}

							// validate feeds
							auto resp = receiveOnly!FeedActorResponse;
							if(resp == FeedActorResponse.INVALID) {
								tasks.remove(f.name);
								return;
							}

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
	 * Debug purpose only ATM
	 */
	@path("/cli") void getCLIEndpoint(scope HTTPServerResponse res)
	{
		string data;
		feedList.match!(
				(InvalidFeeds i) {},
				(RSSFeed[] fl) {
					fl.each!(
						(RSSFeed f) {
							// send task for response from server
							tasks[f.name].send(Task.getThis());

							auto resp = receiveOnly!FeedActorResponse;
							if(resp == FeedActorResponse.INVALID) {
								tasks.remove(f.name);
								return;
							}
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
}

