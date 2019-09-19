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
		struct ChannelItems {
			string cname;
			string fname;
			RSSItem[] items;
		}

		ChannelItems[] channelItems;

		feedList.tryMatch!(
				(RSSFeed[] fl) {
					ChannelItems[] tmpCh;
					fl.each!(
						(RSSFeed f) {
							// send task for response from server
							tasks[f.name].send(Task.getThis());
							// send data request
							tasks[f.name].send(FeedActorRequest.DATA_HTML);

							// receive data length
							auto nch = receiveOnly!RequestDataLength;
							RequestDataLength chRecv = 0;

							while(chRecv < nch) {
								ChannelItems chit;
								chit.fname = f.name;
								chit.cname = receiveOnly!string;

								RequestDataLength nit = receiveOnly!RequestDataLength;
								RequestDataLength iRecv = 0;
								while(iRecv < nit) {
									chit.items ~= receiveOnly!RSSItem;
									iRecv++;
								}
								channelItems ~= chit;
								chRecv++;
							}
						});
					res.render!("index.dt", req, channelItems, fl);
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
