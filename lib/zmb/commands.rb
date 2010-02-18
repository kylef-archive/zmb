class Command
  attr_accessor :delegate, :signal, :help
  
  def initialize(delegate, signal, commands=1, help=nil)
    @delegate = delegate
    @signal = signal
    @help = help
    @commands = commands
  end
  
  def help?
    help != nil
  end
  
  def run(e, args)
    if @commands == 0 then
      args = Array.new
    elsif args.size > @commands
      # Take one under amount of commands
      a = args[0..@commands-2]
      a << args[commands-1..-1].join(' ')
      args = a
    end
    
    begin
      @delegate.send(@signal, e, *args)
    rescue ArgumentError
      'incorrect arguments'
    rescue Exception
      if e.respond_to?('user') and e.user.respond_to?('admin?') and e.user.admin? and e.private? then
        "#{$!.message}\n#{$!.inspect}"
      else
        "command failed"
      end
    end
  end
end

class PermCommand < Command
  attr_accessor :perm
  
  def initialize(perm, *args)
    super(*args)
    @perm = perm
  end
  
  def run(e, args)
    if e.respond_to?('user') and e.user.permission?(@perm) then
      super(e, args)
    else
      'permission denied'
    end
  end
end
