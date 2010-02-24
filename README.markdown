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

- IRC
- Quote
- Relay - Relay between servers and/or channels
- Users - User management
- Bank - Points system

For complete documentation please visit [Documentation](http://kylefuller.co.uk/projects/zmb/)
