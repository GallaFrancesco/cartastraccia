module cartastraccia.rss;

import vibe.core.log;
import std.experimental.xml;
import sumtype;

import std.algorithm.searching : startsWith;
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
	auto cursor = chooseLexer!string
		.parser
		.cursor((CursorError err) {});

	cursor.setSource(feed);

	cursor.enter();
	cursor.enter();
	if(cursor.name == "channel") {
		if(cursor.enter()) {
			alias C = typeof(cursor);
			insertElement!(RSSChannel, RSS, C)(rss, rss, cursor);
			cursor.next();
		}
	}
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
 *   by advancing cursor
*/
void insertElement(ElementType, Parent, C)(
		ref RSS rss, ref Parent parent, ref C cursor) @trusted
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

	while(cursor.kind != XMLKind.elementEnd && cursor.name != elname) {

		immutable name = cursor.name;

		if(name == "item") {

			static if(is(ElementType == RSSChannel)) {
				cursor.enter();
				insertElement!(RSSItem, RSSChannel, C)(rss, newElement, cursor);
				cursor.exit();
			}

		} else if(name.startsWith("atom")){

			logDebug("Skipping atom link identifier: " ~ name);

		} else {

			cursor.enter();
			immutable content = cursor.content;
			cursor.exit();

			fill: switch(name) {

				default:
					logDebug("Invalid XML entry detected: " ~ name);
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

		cursor.next();
	}

	rss.match!(
			(ref InvalidRSS i) {
				logDebug("Invalid XML entry detected: "
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
