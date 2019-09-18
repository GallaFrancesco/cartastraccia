module cartastraccia.endpoint;

import cartastraccia.actor;

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

	@path("/") void getHTMLEndpoint()
	{
		//TODO
	}

	@path("/cli") void getCLIEndpoint(scope HTTPServerResponse res)
	{
		RequestData data;
		feedList.match!(
				(InvalidFeeds i) {},
				(RSSFeed[] fl) {
					fl.each!(
						(RSSFeed f) {
							// send task for response from server
							tasks[f.name].send(Task.getThis());
							// send data request
							tasks[f.name].send(FeedActorRequest.DATA);
							// receive data length
							auto totSize = receiveOnly!RequestDataLength;

							RequestDataLength recSize = 0;

							while(recSize < totSize) {
								data ~= receiveOnly!RequestData;
								recSize += chunkSize;
							}

							data ~= "End of feed: " ~ f.name ~ "\n";

						});
				});

		res.writeBody(data);
	}
}
