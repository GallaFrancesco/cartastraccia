module cartastraccia.config;

import pegged.grammar;
import sumtype;

import core.time;
import std.conv : to;
import std.algorithm : filter;
import std.range;

mixin(grammar(ConfigFileParser));

/**
 * Specify grammar for config file in the form:
 * ...
 * [feed_name] [refresh_time] [feed_address]
 * ...
*/
immutable string ConfigFileParser = `
	ConfigFile:

		ConfigFile <- Feed+

		Feed <- Name space* Refresh space* Address Newline

		Name <- identifier

		Refresh <- Number Timeunit

		Address <- ~([A-Za-z]+ "://" ( !Newline !">" . )+)

		Number 	<-  ~([0-9]+)

		Timeunit <- [mshd]

		Newline <- endOfLine / endOfInput
`;

alias RSSFeedList = SumType!(RSSFeed[], InvalidFeeds);

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

