module cartastraccia.rss;

import cartastraccia.actor : FeedActorRequest;

import vibe.core.log;
import vibe.http.server : render;
import dxml.parser;
import sumtype;

import std.algorithm : startsWith;
import std.range;
import std.conv : to;

public:

alias RSS = SumType!(ValidRSS, InvalidRSS);

/**
 * In case an element was found
 * which does not match the RSS 2.0 specs
 * see: http://www.rssboard.org/rss-specification
 */
struct InvalidRSS {
	// cannot be copied
	@disable this(this);
	string element;
	string content;
}

/**
 * A valid RSS feed is made of various channels
*/
struct ValidRSS {
	// cannot be copied
	@disable this(this);
	RSSChannel[string] channels;
}

/**
 * Each channel has properties
 * and various RSSItems (actual news)
*/
struct RSSChannel {
	// required elements
	string title;
	string link;
	string description;

	// optional elements
	string language;
	string copyright;
	string managingEditor;
	string webMaster;
	string pubDate;
	string lastBuildDate;
	string category;
	string generator;
	string docs;
	string cloud;
	string ttl;
	string image;
	string rating;
	string textInput;
	string skipHours;
	string skipDays;

	RSSItem[string] items;
}

struct RSSItem {
	// required elements
	string title;
	string link;
	string description;

	// optional elements
	string author;
	string cathegory;
	string comments;
	string enclosure;
	string guid;
	string pubDate;
	string source;
}

/**
 * Entry point for dumping a valid rss feed
*/
string dumpRSS(FeedActorRequest dataFormat)(ref ValidRSS rss, immutable string feedName = "")
{
	// cli is mainly for testing functionality
	static if(dataFormat == FeedActorRequest.DATA_CLI) {

		string res;

		foreach(cname, ref channel; rss.channels) {
			res ~= "\n===\n~"
				~ cname ~ "\n"
				~ channel.link ~ "\n"
				~ channel.description ~ "\n"
				~ "\n===\n";
			ulong cnt = 0;
			foreach(iname, item; channel.items) {
				res ~= " " ~ cnt.to!string ~ ". "
					~ item.title ~ "\n"
					~ item.link ~ "\n"
					~ "---\n"
					~ item.description ~ "\n---\n";
				cnt++;
			}
		}
		return res;

	// generate a valid HTML dump from the given rss struct
	} else if(dataFormat == FeedActorRequest.DATA_HTML) {
		// TODO
	} else logFatal("Invalid data format received from webserver.");
}

/**
 * Entrypoint for parsing a rss feed (repsesented as string)
*/
void parseRSS(ref RSS rss, immutable string feed) @trusted
{
	auto rssRange = parseXML!simpleXML(feed);
	if(rssRange.front.name == "html") {
		logWarn("Unable to parse HTML file");
		rss = InvalidRSS("html", "");
		return;
	}

	while(rssRange.front.name != "channel") {
		rssRange.popFront();
	}
	rssRange.popFront();

	alias C = typeof(rssRange);
	insertElement!(RSSChannel, RSS, C)(rss, rss, rssRange);
}


private:

/**
 * Insert an element (RSSChannel or RSSItem) which has:
 * - A parent (be it the RSS xml root (RSSChannel
 *   or the RSSChannel in case of an RSSItem
 * - Various sub-entries which are processed sequentially
 *   by advancing rssRange
*/
void insertElement(ElementType, Parent, C)(
		ref RSS rss, ref Parent parent, ref C rssRange) @trusted
{
	ElementType newElement;

	mixin(selectElementName);

	// advance the parser to completion, entry by entry
	while(rssRange.front.type != EntityType.elementEnd
			&& rssRange.front.type != EntityType.text
			&& rssRange.front.name != elname) {

		immutable name = rssRange.front.name;
		rssRange.popFront();

		if(name == "item") {

			// recursively insert items
			static if(is(ElementType == RSSChannel)) {
				insertElement!(RSSItem, RSSChannel, C)(rss, newElement, rssRange);
			} else {
				rss = InvalidRSS(name, "");
			}

		} else if(rssRange.front.type == EntityType.text
				|| rssRange.front.type == EntityType.cdata) {

			// found a valid text field
			immutable content = rssRange.front.text;
			rssRange.popFront();

			fill: switch(name) {

				default:
					// we don't care about entries which are not attributes of RSSChannel
					logDebug("Ignoring XML Entity: " ~ name);
					break fill;

				// inserting a channel
				static if(is(ElementType == RSSChannel)) {
					static foreach(m; __traits(allMembers, RSSChannel)) {
						static if(m != "items") {
							case m:
								mixin("newElement."~m~" = content;");
								break fill;
						}
					}

				// inserting an item
				} else if(is(ElementType == RSSItem)) {
					static foreach(m; __traits(allMembers, RSSItem)) {
							case m:
								mixin("newElement."~m~" = content;");
								break fill;
					}

				// should not get here (means function invocation was invalid)
				} else assert(false, "Invalid ElementType requested");
			}
		}
		// skip elementEnd
		rssRange.popFront();
	}

	// finished channel / item parsing. Insert it into rss struct
	rss.match!(
			(ref InvalidRSS i) {
				logWarn("Invalid XML Entity detected: "
						~ i.element
						~ ": "
						~ i.content);
				},
			(ref ValidRSS v) {
					static if(is(ElementType == RSSChannel))
						parent.tryMatch!(
							(ref ValidRSS v) {
								v.channels[newElement.title] = newElement;
							});
					else if(is(ElementType == RSSItem))
						parent.items[newElement.title] = newElement;
					logInfo("Inserted " ~ elname ~ ": " ~ newElement.title);
				});
}

static immutable string selectElementName = "
	string elname;

	static if(is(ElementType == RSSChannel)) {
		elname = \"channel\";
		static assert(is(Parent == RSS));
	} else if(is(ElementType == RSSItem)) {
		elname = \"item\";
		static assert(is(Parent == RSSChannel));
	} else assert(false, \"Invalid ElementType provided\");
";

