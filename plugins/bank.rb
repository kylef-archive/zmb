class Account
  attr_accessor :username, :balance, :log
  
  def initialize(username, balance=0)
    @username = username
    @balance = balance
    @log = Array.new
    log 'Opening account'
  end
  
  def self.create_settings(settings)
    require 'time'
    account = new(settings['username'], settings['balance'])
    account.log = settings['log']
    account
  end
  
  def to_json(*a)
    { 'username' => @username, 'balance' => @balance, 'log' => @log }.to_json(*a)
  end
  
  def log(message)
    @log << { 'message' => message, 'balance' => @balance, 'time' => Time.now }
  end
  
  def funds?(amount)
    @balance >= amount
  end
  
  def transaction(amount, message=nil)
    @balance += amount
    log message if message
  end
  
  def transfer(account, amount)
    transaction(amount*-1, "#{amount} transfered to #{account.username}")
    account.transaction(amount, "#{amount} transfered from #{@username}")
  end
end

class Event
  attr_accessor :bank
end

class Bank
  attr_accessor :accounts
  
  def initialize(sender, settings={})
    @accounts = settings['accounts'].map{ |acc| Account.create_settings(acc) } if settings.has_key?('accounts')
    @accounts = Array.new if not @accounts
  end
  
  def to_json(*a)
    { 'accounts' => @accounts, 'plugin' => 'bank' }.to_json(*a)
  end
  
  def create(username)
    account = Account.new(username)
    @accounts << account
    account
  end
  
  def account!(username)
    @accounts.find{|account| account.username == username}
  end
  
  def account(username)
    account!(username) or create(username)
  end
  
  def pre_event(sender, e)
    e.bank = account(e.user.username) if e.respond_to?('user') and e.user.respond_to?('username')
  end
  
  def commands
    require 'zmb/commands'
    {
      'balance' => AuthCommand.new(self, :balance, 0, 'See how much funds you have.'),
      'transfer' => AuthCommand.new(self, :transfer, 2, 'Transfer funds to another account'),
    }
  end
  
  def balance(e)
    "Your balance is #{e.bank.balance}"
  end
  
  def transfer(e, username, amount)
    amount = Integer(amount)
    return "#{e.user.username} attempted theft against #{username}" if amount < 0
    return 'funds not availible' if not e.bank.funds?(amount)
    return "#{username} doesn't appear to have a bank account, they need to open one with the balance command" if not r = account!(username)
    e.bank.transfer(r, amount)
    "#{amount} transfered to #{username}'s account"
  end
end

Plugin.define do 
  name "bank"
  description "virtual bank/money system"
  object Bank
end