/**
 * Copyright (c) 2020 Francesco Galla` - <me@fragal.eu>
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
 * Ascii art for the title bar of Cartastraccia.
 * ---
 * Credits to http://www.patorjk.com/software/taag/
 * for the incredibly useful and enjoyable tool.
 *
*/

module cartastraccia.asciiart;

static immutable string asciiArt = r"
 ▄████▄   ▄▄▄       ██▀███  ▄▄▄█████▓ ▄▄▄           ██████ ▄▄▄█████▓ ██▀███   ▄▄▄       ▄████▄   ▄████▄   ██▓ ▄▄▄      
▒██▀ ▀█  ▒████▄    ▓██ ▒ ██▒▓  ██▒ ▓▒▒████▄       ▒██    ▒ ▓  ██▒ ▓▒▓██ ▒ ██▒▒████▄    ▒██▀ ▀█  ▒██▀ ▀█  ▓██▒▒████▄    
▒▓█    ▄ ▒██  ▀█▄  ▓██ ░▄█ ▒▒ ▓██░ ▒░▒██  ▀█▄     ░ ▓██▄   ▒ ▓██░ ▒░▓██ ░▄█ ▒▒██  ▀█▄  ▒▓█    ▄ ▒▓█    ▄ ▒██▒▒██  ▀█▄  
▒▓▓▄ ▄██▒░██▄▄▄▄██ ▒██▀▀█▄  ░ ▓██▓ ░ ░██▄▄▄▄██      ▒   ██▒░ ▓██▓ ░ ▒██▀▀█▄  ░██▄▄▄▄██ ▒▓▓▄ ▄██▒▒▓▓▄ ▄██▒░██░░██▄▄▄▄██ 
▒ ▓███▀ ░ ▓█   ▓██▒░██▓ ▒██▒  ▒██▒ ░  ▓█   ▓██▒   ▒██████▒▒  ▒██▒ ░ ░██▓ ▒██▒ ▓█   ▓██▒▒ ▓███▀ ░▒ ▓███▀ ░░██░ ▓█   ▓██▒
░ ░▒ ▒  ░ ▒▒   ▓▒█░░ ▒▓ ░▒▓░  ▒ ░░    ▒▒   ▓▒█░   ▒ ▒▓▒ ▒ ░  ▒ ░░   ░ ▒▓ ░▒▓░ ▒▒   ▓▒█░░ ░▒ ▒  ░░ ░▒ ▒  ░░▓   ▒▒   ▓▒█░
  ░  ▒     ▒   ▒▒ ░  ░▒ ░ ▒░    ░      ▒   ▒▒ ░   ░ ░▒  ░ ░    ░      ░▒ ░ ▒░  ▒   ▒▒ ░  ░  ▒     ░  ▒    ▒ ░  ▒   ▒▒ ░
░          ░   ▒     ░░   ░   ░        ░   ▒      ░  ░  ░    ░        ░░   ░   ░   ▒   ░        ░         ▒ ░  ░   ▒   
░ ░            ░  ░   ░                    ░  ░         ░              ░           ░  ░░ ░      ░ ░       ░        ░  ░
░                                                                                      ░        ░                      

";

static immutable string BANNER = "==========================================================================
|               Carta Straccia is a RSS feed aggregator                  |
==========================================================================";

static immutable string QUICKSTART = "
Quickstart
--------------------------------------------------------------------------
0. Write a feeds.conf file [feed_name refresh_timeout feed_url]
> echo \"Stallman 3h https://stallman.org/rss/rss.xml\" > feeds.conf
--------------------------------------------------------------------------
1. Start the daemon:
> cartastraccia --daemon --feeds=feeds.conf
--------------------------------------------------------------------------
2. Connect to daemon using HTML browser
> elinks 'https://localhost:8080'
==========================================================================
";
