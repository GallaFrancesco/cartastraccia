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
 * Config (feeds) file parsing.
 *
*/

module cartastraccia.config;

import pegged.grammar;
import sumtype;

import core.time;
import std.datetime;
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
