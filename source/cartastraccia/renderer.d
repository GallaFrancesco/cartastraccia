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
	doc.root.html = `<head>
			<meta charset="UTF-8">
			<link href="../css/channel.css"rel="stylesheet" type="text/css">
			<title>Cartastraccia - `~feedName~`</title>
			</head>`;

	foreach(cname, channel; rss.channels) {
		auto chCont = doc.createElement("div", doc.root.firstChild);
		chCont.attr("class", "channel");
		chCont.attr("id", feedName);
		chCont.html = "<h1>"~cname~"</h2>";

		auto row = doc.createElement("div", doc.root.firstChild);
		row.attr("class", "row");

		auto icnt = channel.items.length;

		auto column1 = doc.createElement("div", doc.root.firstChild);
		column1.attr("class", "channelitem");
		auto column2= doc.createElement("div", doc.root.firstChild);
		column2.attr("class", "channelitem");

		uint i=0;
		foreach(iname, item; channel.items) {
			if(i < icnt/2) {
				auto itemCont = doc.createElement("div", column1);
				itemCont.html = "<h2>"~iname~"</h2>"
					~ "<b><a href="~item.link~">View Source</a></b>"
					~ "<p>"~item.pubDate~"</p>"
					~ item.description;
			} else {
				auto itemCont = doc.createElement("div", column2);
				itemCont.html = "<h2>"~iname~"</h2>"
					~ "<b><a href="~item.link~">View Source</a></b>"
					~ "<p>"~item.pubDate~"</p>"
					~ item.description;
			}
			i++;
		}
	}

	auto output = appender!string;
	doc.root.outerHTML(output);

	immutable fpath = NativePath(pageName);
	if(existsFile(fpath)) removeFile(fpath);
	appendToFile(fpath, output.data);
}
