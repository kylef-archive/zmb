## zmb messenger bot

zmb is a complete messenger bot supporting irc, and command line interface.

### Install
	gem install zmb

### Uninstall
	gem uninstall zmb
	rm -rf ~/.zmb # If you used the default settings location

### Creating a bot

This command will use the default settings location of ~/.zmb, you can pass `-s <PATH>` to change this.

	zmb --create

### Launching the bot
	zmb --daemon

### Using the bot in command shell mode

You can run zmb in a shell mode to test plugins without even connecting to any irc servers. It will create a shell where you can enter commands.

	zmb --shell

### Included plugins

- IRC - Connect to a IRC server
- Quote - Quotes
- Poll - Voting system
- Relay - Relay between servers and/or channels
- Users - User management
- Log - Log everything said in a channel
- GCalc - Execute a expression using google calculator
- Announce - Send message to a channel automatically in a certain amount of time
- DNS - Perform DNS, RDNS and whois lookups
- NickServ - Log into NickServ
- Security - Hashes, rot13, and morse code
- Random - Pick a random value from a list, yes or no, coinflip
- URL - Dpaste, pastie, bitly, tinyurl, isgd
- Bank - Points system

#### Other features

- Piping commands together

    .help | pastie

### Support

You can find support at #zmb @ efnet.

For complete documentation please visit [Documentation](http://kylefuller.co.uk/projects/zmb/)
