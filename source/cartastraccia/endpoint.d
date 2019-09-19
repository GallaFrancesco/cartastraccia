module cartastraccia.endpoint;

import cartastraccia.config;
import cartastraccia.actor;
import cartastraccia.rss;

import vibe.core.log;
import vibe.core.task;
import vibe.core.concurrency;
import vibe.http.router;
import vibe.web.web;
import sumtype;

import std.algorithm : each;

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

	this(RSSFeedList fl, TaskMap tm)
	{
		feedList = fl;
		tasks = tm;
	}

	@path("/") void getHTMLEndpoint(scope HTTPServerRequest req, scope HTTPServerResponse res)
	{
		RSSFeed[] validFeeds;
		feedList.match!(
				(InvalidFeeds i) {},
				(RSSFeed[] fl) {
					fl.each!(
						(RSSFeed f) {
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

							validFeeds ~= f;
						});
					feedList = validFeeds;
					res.render!("index.dt", req, validFeeds);
				});
	}

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
