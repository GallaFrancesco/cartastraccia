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

import cartastraccia.actor;

import pegged.grammar;
import sumtype;

import core.time;
import std.datetime;
import std.conv : to;
import std.algorithm : filter;
import std.range;
import std.file : readText;

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

/**
 * Populate a list of structures 
 * containing data parsed from feed.conf
 */
RSSActorList loadFeedsConfig(immutable string feedsFile)
{

	auto pt = ConfigFile(readText(feedsFile));
	if(!pt.successful) {
		return RSSActorList(InvalidFeeds("Unable to parse config."));
	}
	return processFeeds(pt);
}
