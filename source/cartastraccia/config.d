module cartastraccia.config;

import pegged.grammar;

mixin(grammar(ConfigFileParser));

/**
 * Specify grammar for config file in the form:
 * ...
 * [feed_name] [refresh_time] [feed_address]
 * ...
*/
immutable string ConfigFileParser = `
	ConfigFile:

		ConfigFile <- Feed* (Newline Feed)*

		Feed <- Name space* Refresh space* Address

		Name <- identifier

		Refresh <- Number Timeunit

		Address <- ~([A-Za-z]+ "://" ( !Newline !">" . )+)

		Number 	<-  ~([0-9]+)

		Timeunit <- [mshd]

		Newline <- endOfLine

`;
