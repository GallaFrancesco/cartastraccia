module cartastraccia.actor;

import std.algorithm : each;
import std.stdio;
import vibe.core.log;

import pegged.grammar;

void processFeeds(ParseTree pt) @trusted
{
	foreach(ref conf; pt.children) {
		foreach(ref feed; conf.children) {
		}
	}
}

