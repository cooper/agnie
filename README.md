# agnie

Yes.  
It really is an IRC daemon.  
It's written in Perl.  
  
...  
You can breathe again.  
There. Very good.  

# Introduction

This is juno-ircd, an IRC server daemon written in the Perl programming language. Why,
you ask? No one knows for sure. Perl and IRC are both neat, so why not?  

This software will probably surprise you with its functionality and features. However, it
should by no means be considered stable. Throughout several years of development, no
stable versions have been released. Nonetheless, you are encouraged to give it a try.

## Concepts

* __Eventedness__: The core unifying policy of juno-ircd is the excessive use of events.
It is the fundamental and single most important concept in mind throughout the IRCd.
Any operation that occurs can be represented as an event, and anything where it may seem
useful for something to respond, an event exists and is fired. This functionality is
provided by [Evented::Object](https://github.com/cooper/evented-object), a showcase
project that is the base of every class within the IRCd.

* __Extensibility__: Through the use of events and other mechanisms, extensibility is
another important guideline around which juno is designed. It should not be assumed that
any commands, modes, prefixes, etc. are permanent or definite. They should be changeable
and replaceable, and it should be possible for more to be added with ease.

* __Modularity__: By responding to events, modules add new features and functionality to
the IRCd. Without them, juno is made up of a mere sixty lines of Perl code. Everything else
is within a module. Modules communicate and work together to create a single functioning
body whose parts can be added, removed, and modified. This functionality is provided by
the [Evented::API::Engine](https://github.com/cooper/evented-api-engine), a class which
provides an interface for loading and managing modules.

* __Upgradability__: The beauty of Perl makes it practical for an entire piece of software
to be upgraded or reloaded without restarting it. With the help of the API engine and
modularity as a central principle, juno aims to do exactly that. With just one command,
you can jump from version 10 to 25, all without your users disconnecting.

* __Configurability__: Very few values are hard coded. Some have default values, but
nearly everything is configurable. There's little reason to make limitations on what can
and cannot be changed, so tons of configurable options make it easy to set the server up
exactly as you please. Made possible by
[Evented::Configuration](https://github.com/cooper/evented-configuration) and
[Evented::Database](https://github.com/cooper/evented-database).

* __Efficiency__: Processing efficiency is valued over memory friendliness. I believe that
a more responsive server is better than one that runs on very minimal resources. Modern
IRC servers typically have a higher per-user load and therefore should be prompt at
fulfilling request after request. Utilizing the wonderful
[IO::Async](http://search.cpan.org/perldoc/IO::Async) framework, juno is quite reactive.

## Features

This section isn't done.

# Modules

This section isn't done.

* __ircd__:

* __Core__:

* __Resolve__:

* __Ident__:

* __JELP__:

* __Channel::Access__:

* __Account__:

* __Modules__:

* __Reload__:

* __Eval__:

* __Fantasy__:

* __Git__:

* __LOLCAT__:

* __Invite__: 

# History

juno-ircd was born a fork of [pIRCd](http://pircd.sourceforge.net) (the Perl IRC daemon)
but has since been rewritten (multiple times) from the ground up.

* [__pIRCd__](http://pircd.sourceforge.net):
Born in the 20th century and written by Jay Kominek, pIRCd is a very buggy,
poorly-coded, feature-lacking (well, compared to those now) IRC server. During its time,
it was one of only a number of IRCds featuring SSL support. Having been abandoned in 2002,
pIRCd is ancient history.

* __pIRCd2__:
A PHP novice, I was convinced by someone to learn Perl. I discovered pIRCd
and spent hours trying to change something without breaking it. pIRCd2 allowed you to use
the dollar sign ($) in nicknames, adding support for users such as
[Ke$ha](https://twitter.com/KeshaRose). Truly revolutionary to IRC as a whole.

* [__juno-ircd__](https://github.com/cooper/juno1) (juno1):
A fork of pIRCd2, juno-ircd introduced a handful of new features:
five prefixes (~&@%+), CAP and multi-prefix support, channel link mode (+L), internal
logging channel (inspired by InspIRCd), network administrator support and the
corresponding NA:line, temporary oper-override mode (+O), channel mute mode (+Z, inspired
by charybdis +q), KLINE command for adding K:lines from IRC, an almost-but-never-fully
working buggy linking protocol, and a network name (NETWORK in RPL_ISUPPORT) option.
juno-ircd's name was chosen by [Autumn](https://github.com/lacp) after the Roman goddess
[Juno](http://en.wikipedia.org/wiki/Juno_(mythology)).
Unfortunately it introduced dozens of new bugs along with its features, and it
included some of the ugliest code in all of Perl history.
An example of the attention juno-ircd received from the [Atheme](http://atheme.org)
(then StaticBox) community:

```
[04:15pm] -Global- [Network Notice] Alice (nenolod) - We will be upgrading to "juno-ircd" in 5 seconds.
```

* [__juno__](https://github.com/cooper/juno2) (juno2):
At some point, some [IRC bullies](http://stop-irc-bullying.eu) made me
realize how horrific juno-ircd was. I decided to dramatically announce that I would no
longer be developing the project, but I could not resist. I started from scratch, dropping
the '-ircd' from the name. juno was actually quite complete and surprisingly reliable.
Unlike pIRCd and its derivatives, it introduced an interface for modules which later
became a separate project, [API Engine](https://github.com/cooper/api-engine). It
brought forth more new features than can be mentioned, namely: host cloaking, server
notices, channel access mode (+A), GRANT command, D:line, lots more. juno unfortunately
was completely incapable of server linkage.

* [__juno3__](https://github.com/cooper/juno3):
It occurred to me one day that an IRC server incapable of linking is somewhat
impractical (as if one written in Perl were not impractical enough already). I decided to
put the past behind and say goodbye to juno2. Another complete rewrite, juno3's showcase
improvement was a dazzling linking protocol. It was even more extensible than ever before
with greatly improved module interfaces. juno3 was also the first version to make use of
[IO::Async](http://search.cpan.org/perldoc/IO::Async), exponentially boosting its speed
efficiency. Although it required more memory resources than juno2, it was prepared to
take on a massive load, tested with many tens of thousands of users. It was less buggy
but also less featureful, lacking many standard IRC functions due to my shift of focus to
a reliable core.

* [__juno-mesh__](https://github.com/cooper/juno-mesh) (juno4): It was recommended to me
by [Andrew Sorensen](http://andrewsorensen.net) (AndrewX192) that I should implement
mesh server linking. It seemed that it would be easy to implement, so I forked juno3 to
create juno-mesh. In addition to mesh linking, it introduced several new commands and a
new permission system with a method by which additional statuses/prefixes can be added.

* [__juno5__](https://github.com/cooper/kylie/tree/f0d3e8f31062faa894ae1d8db3c0796630b2ee42):
It turned out that mesh linking required more code and effort than intended and introduced
countless bugs that I didn't want to bother correcting. I knew that if I started from
scratch again, it would never reach the completeness of the previous generation. Therefore,
juno5 was born as yet another fork that removes the mesh capability while preserving the 
other new features that were introduced in juno-mesh. 

* [__kedler__](https://github.com/cooper/kylie/tree/4fec4b52841eaca3a43003df8f979ac098bb367d) (juno6): 
Named after a Haitian computer technician, kedler was a continuation of juno5. Its main goal was
to implement the missing standard IRC functions that had never been implemented in the
third juno generation. kedler reintroduced hostname resolving, a long-broken feature that
had not worked properly since juno2. It also reintroduced channel access, this time in the
form of a module. kedler featured new APIs and improvements to the linking protocol.

* [__vulpia__](https://github.com/cooper/kylie/tree/001b766439ed8423e8eda1c41dd578c899cd7946) (juno7):
Romanian for a female wolf, vulpia was named after the alias of a dear friend,
[Ruin](https://soundcloud.com/ruuuuuuuuuuuuin). It included several improvements, making
the IRCd more extensible than ever before. The
[Evented::API::Engine](https://github.com/cooper/evented-api-engine) replaced the former
[API Engine](https://github.com/cooper/api-engine), allowing modules to react to any
event that occurs within juno. vulpia completed the relocation of JELP
(the linking protocol) to a module, opening the doors for additional linking protocols
in the future. Additionally, it established the Account module, allowing users to better
manage accounts and channels.

* [__kylie__](https://github.com/cooper/kylie/tree/4512ebcd3b526781662ca9f3588df285ed1290da) (juno8):
Named after the adored [Kyle](http://mac-mini.org) (mac-mini), kylie introduced several
previously-missing core components including
[ident](http://en.wikipedia.org/wiki/Ident_protocol) support and channel modes: limit,
secret, and key. APIs for [IRCv3](http://ircv3.org) extensions were added, allowing
[SASL](http://ircv3.org/extensions/sasl-3.1),
[multi-prefix](http://ircv3.org/extensions/multi-prefix-3.1), and
[message tag](http://ircv3.org/specification/message-tags-3.2) support. An improved IRC
parameter parser allowed drastic code cleanup and improved efficiency. A new event-driven
command API made user commands more extensible than ever before. The migration of all
non-modular packages into modules significantly improved the stability and reloadability
of the IRCd.

* [__agnie__](https://github.com/cooper/agnie) (juno9):
Named after the beautiful and talented [Agnes](http://agnes.mac-mini.org), agnie is a
continuation of kylie. It is the current version under active development.

# Installation and operation

Most actions for starting, stopping, and managing the IRC server are committed with the
`juno` script in the root directory of the repository.

## Installation

Before installing juno, a number of Perl packages must be installed to the system. The
simplest way to install them is with the `cpanm` tool, but you can use any CPAN client
or package manager of your choice (assuming it has the latest versions).  

To install `cpanm`, run the following command:

```bash
curl -L http://cpanmin.us | perl - --sudo App::cpanminus
```

Then, install these modules:

```bash
cpanm --sudo IO::Async IO::Socket::IP Socket::GetAddrInfo JSON JSON::XS
```

If you want to use any module which requires database (such as Account), install this:

```bash
cpanm --sudo DBD::SQLite
```

After you've installed the appropriate Perl packages, clone the repository:

```bash
git clone --recursive https://github.com/cooper/kylie.git
# OR (whichever is available on your git)
git clone --recurse-submodules https://github.com/cooper/kylie.git
```

Now you need to configure it.

## Configuration

juno actually comes with a working example configuration. If you want to try it for the
first time, simply copy `etc/ircd.conf.example` in to `etc/ircd.conf`. The password for
the default oper account `admin` is `k`.  

The configuration is, for the most part, self-explanitory. Anything that might be
questionable probably has a comment that explains it.

## Starting, stopping, etc.

These options are provided by the `juno` script.

```
usage: ./juno [action]
    start       start juno IRCd
    forcestart  attempt to start juno under any circumstances
    stop        terminate juno IRCd
    debug       start in NOFORK mode with printed output
    forever     run continuously
    foreverd    run continuously in debug mode
    rehash      rehash the server configuration file
    mkpasswd    runs the password generator
    dev         various developer actions (./juno dev help)
    help        print this information
```

* __start__: Runs the server in the background as a daemon.

* __forcestart__: Runs the server in the background, ignoring the PID file if it appears
to already be running.

* __stop__: Terminates the IRCd if it is currently running.

* __debug__: Runs the IRCd in the foreground, printing the logging output.

* __forever__: Runs the IRCd continuously in the background. In other words, if it is
stopped for any reason (such as a crash or exploit or SHUTDOWN), it will immediately
start again. Don't worry though, it will not stress out your processor if it fails
over and over.

* __foreverd__: Runs the IRCd continuously in the foreground, printing the logging output.

* __rehash__: Notifies the currently-running server to reload its configuration file.

* __mkpasswd__: Runs the script for generating encrypted passwords for use in oper and
connect blocks in the server configuration.

* __dev__: Includes a number of subcommand tools for developers; see `./juno dev help`.

## Upgrading

To upgrade an existing repository, run the following commands:

```
git pull origin master
git submodule update --init
```

Then, assuming the Reload module is loaded on your server, use the `RELOAD` command to
upgrade the server without restarting. Because there are no stable releases, the
possibility for this to fail is definitely there. Perhaps one day we will have stable
releases that are known to upgrade without error.

# Information

Here you will find contacts, licensing, development information, etc. 

## Getting help

If you need any help with setting up or configuring juno, visit us on NoTrollPlzNet IRC at
`irc.notroll.net 6667 #k`. I love new ideas, so feel free to recommend a feature or fix
here as well. In fact, I encourage you to visit me on IRC because many parts of this
software are poorly documented or not documented at all. Sadly, most of the "documentation"
lives only in my head at the moment, but I'll gladly tell you anything you may wish to
know about the IRCd.

## Helping me out

If you are interested in assisting with the development of this software, please visit me
on IRC at `irc.notroll.net port 6667 #k`. I am willing to hear your ideas whether
or not you are a developer, in fact.  

If you are interested in writing modules for juno-ircd, please contact me on IRC because
the APIs are not yet fully documented. I will gladly give you a tour of juno-ircd's
several programming interfaces!

## Versions, changes, and plans

See INDEV for a changelog and TODO list. It has been extended throughout all versions of
this software starting with juno-ircd (juno1). The newest changes are at the bottom.
The current version is in the VERSION file. Planned features are in the GOALS file
(but I forget to update that sometimes).

## Author

Mitchell Cooper, mitchell@notroll.net  

I use Unix-like systems, and much of my work is designed specifically for such.
I would be surprised yet pleased if someone got this software working on Windows. If the
Xcode project isn't a good enough indication, I currently use OS X to develop this software.
I don't think it's appropriate for Perl, but I have not yet found a great OS X editor.

I live in the middle of nowhere and prefer the dark chicken meat over white meat. I'll
drink a Coke if there's no better option, but I'd take a Sunkist, Pepsi or Dr. Pepper first.
I don't watch much television, but when I do, it's usually on news networks, C-SPAN, and
night shows.
  
I repair computers and visit people's homes to help with their electronic troubles.
I've designed websites for local entities in the area. I collect computers and have
gradually removed items from my home to make more room for them. Some of my friends have
tagged me a "computer hoarder."

I always feel that I'm too busy to do anything and therefore accomplish almost nothing. I
am a lazy procrastinator but work well under the pressure of time limits. During my
"free time," I ride a motorized bike for hours even further into the middle of nowhere
without reason. I garden during the summer: Asparagus and onions are my favorite.

juno-ircd was my first project in Perl — ever.
Most of my creations in Perl are related to IRC in some way, but I have other projects as
well. I always look back at things I worked on a month ago and realize how terrible they
are. That is why there are several rewrites of the same IRCd. I am, however, quite proud
of the cleanliness of the current version.

## License

juno-ircd version 3 and all of its derivatives (including this one) are licensed under the
three-clause "New" BSD license. A copy of this license should be included with all
instances of this software source, either in the root directory or in the 'doc' directory.
