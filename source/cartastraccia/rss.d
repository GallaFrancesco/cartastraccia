module cartastraccia.rss;

import vibe.core.log;
import dxml.parser;
import sumtype;

import std.algorithm : startsWith;
import std.range;
import std.conv : to;

public:

alias RSS = SumType!(ValidRSS, InvalidRSS);
alias RSSParent = SumType!(RSS, RSSChannel);

/**
 * In case an element was found
 * which does not match the RSS 2.0 specs
 * see: http://www.rssboard.org/rss-specification
 */
struct InvalidRSS {
	string element;
	string content;
}

/**
 * A valid RSS feed is made of various channels
*/
struct ValidRSS {
	RSSChannel[string] channels;
}

/**
 * Each channel has properties
 * and various items (actual news)
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

// mainly for debugging purposes
string dumpRSScli(ref RSS rss)
{
	string res;

	rss.match!(
			(InvalidRSS i) {
					res = "Invalid RSS feed";
				},
			(ValidRSS vr) {
				foreach(cname, channel; vr.channels) {
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
			});
	return res;
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

	string elname;

	static if(is(ElementType == RSSChannel)) {
		elname = "channel";
		static assert(is(Parent == RSS));
	} else if(is(ElementType == RSSItem)) {
		elname = "item";
		static assert(is(Parent == RSSChannel));
	} else assert(false, "Invalid ElementType provided");

	while(rssRange.front.type != EntityType.elementEnd
			&& rssRange.front.type != EntityType.text
			&& rssRange.front.name != elname) {

		immutable name = rssRange.front.name;
		rssRange.popFront();

		if(name == "item") {

			static if(is(ElementType == RSSChannel)) {
				insertElement!(RSSItem, RSSChannel, C)(rss, newElement, rssRange);
			} else {
				rss = InvalidRSS(name, "");
			}

		} else if(name.startsWith("atom")){

			logDebug("Skipping atom link identifier: " ~ name);

		} else if(rssRange.front.type == EntityType.text
				|| rssRange.front.type == EntityType.cdata) {

			immutable content = rssRange.front.text;
			rssRange.popFront();

			fill: switch(name) {

				default:
					logDebug("Ignoring XML Entity: " ~ name);
					break fill;

				static if(is(ElementType == RSSChannel)) {
					static foreach(m; __traits(allMembers, RSSChannel)) {
						static if(m != "items") {
							case m:
								mixin("newElement."~m~" = content;");
								break fill;
						}
					}

				} else if(is(ElementType == RSSItem)) {
					static foreach(m; __traits(allMembers, RSSItem)) {
							case m:
								mixin("newElement."~m~" = content;");
								break fill;
					}

				} else {
					assert(false, "Invalid ElementType requested");
				}
			}
		}

		rssRange.popFront();
	}

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
								(ref ValidRSS v) => v.channels[newElement.title] = newElement);
					else if(is(ElementType == RSSItem))
						parent.items[newElement.title] = newElement;
					logInfo("Inserted " ~ elname ~ ": " ~ newElement.title);
				});
}
