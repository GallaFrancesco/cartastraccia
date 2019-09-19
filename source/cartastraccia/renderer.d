module cartastraccia.renderer;

import cartastraccia.rss;

import html;
import vibe.core.file;
import vibe.core.path;

import std.conv : to;
import std.stdio;
import std.array : appender;

void createHTMLPage(ref ValidRSS rss, immutable string feedName, immutable string pageName)
{
	auto doc = createDocument();
	doc.root.html = `<body>&nbsp;</body>`;

	foreach(cname, channel; rss.channels) {
		auto container = doc.createElement("div", doc.root.firstChild);
		container.attr("class", "channel");
		container.attr("id", feedName);
		container.html = "<h1>"~cname~"</h2>";

		ulong icnt = 0;
		foreach(iname, item; channel.items) {
			icnt++;
			auto container = doc.createElement("div", doc.root.firstChild);
			container.attr("class", "channelitem");
			container.html = "<h2>"~icnt.to!string~". "~iname~"</h2>"
				~ "<b><a href="~item.link~">View Source</a></b>"
				~ "<p>"~item.pubDate~"</p>"
				~ item.description;
		}
	}

	auto output = appender!string;
	doc.root.outerHTML(output);

	immutable fpath = NativePath(pageName);
	if(existsFile(fpath)) removeFile(fpath);
	appendToFile(fpath, output.data);
}
