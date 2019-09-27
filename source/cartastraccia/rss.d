module cartastraccia.rss;

import cartastraccia.actor : FeedActorRequest;
import cartastraccia.include.mrss;

import vibe.core.log;
import vibe.http.server : render;
import sumtype;

import std.algorithm : startsWith, sort, move;
import std.datetime;
import std.range;
import std.conv : to;
import std.string;

public:

alias RSS = SumType!(ValidRSS, InvalidRSS, FailedRSS);


/**
 * In case the RSS feed couldn't be loaded
 */
struct FailedRSS {
	@disable this(this);
	string msg;
}

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
	RSSChannel channel;
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

	RSSItem[] items;
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

		res ~= "\n===\n~"
			~ rss.channel.title ~ "\n"
			~ rss.channel.link ~ "\n"
			~ rss.channel.description ~ "\n"
			~ "\n===\n";

			uint cnt = 1;
			foreach(item; rss.channel.items) {
				res ~= " " ~ cnt.to!string ~ ". "
					~ item.title ~ "\n"
					~ item.link ~ "\n"
					~ "---\n"
					~ item.description ~ "\n---\n";
				cnt++;
			}
		return res;

	// generate a valid HTML dump from the given rss struct
	} else logFatal("Invalid data format received from webserver.");
}

void parseRSS(ref RSS rss, string feed) @trusted
{
	mrss_t* rssData;
	size_t len;
	auto fz = feed.toZString(len);
	mrss_error_t err = mrss_parse_buffer(fz, len, &rssData);

	if(err) {
		rss = InvalidRSS("mrss", err.to!string);

	} else {
		rss = ValidRSS();

		rss.tryMatch!(
			(ref ValidRSS vrss) {
				newChannel(rssData, vrss);

				mrss_item_t* item = rssData.item;
				while(item) {
					newItem(item, vrss);
					item = item.next;
				}
			});
	}

	// parse date and sort in descending order (newest first)
	rss.tryMatch!(
			(ref InvalidRSS i) {
				return;
			},
			(ref ValidRSS vr) {
				vr.channel.items.sort!( (i,j) {
						return (parseRFC822DateTime(i.pubDate)
						 > parseRFC822DateTime(j.pubDate));
				});
			});
}

private:

void newChannel(mrss_t* rssData, ref ValidRSS rss)
{
	static foreach(m; __traits(allMembers, RSSChannel)) {
		static if(is(typeof(__traits(getMember, mrss_t, m)) == char*)) {
			mixin("rss.channel."~m~" = rssData."~m~".ZtoString.idup;");
		}
	}
}

void newItem(mrss_item_t* rssItem, ref ValidRSS rss)
{
	RSSItem newItem;

	static foreach(m; __traits(allMembers, RSSItem)) {
		static if(is(typeof(__traits(getMember, mrss_item_t, m)) == char*)) {
			mixin("newItem."~m~" = rssItem."~m~".to!string;");
		}
	}

	rss.channel.items ~= newItem;
}

string ZtoString(const char* c)
{
    if (c !is null)
      return to!string(fromStringz(c));
    else
      return null;
}

auto toZString(string s, ref size_t len)
{
	char[] ret = s.to!(char[]);
	if (ret[$-1] != '\0')
		ret ~= "\0".to!(char[]);
	len = ret.length;
	return ret.ptr;
}
