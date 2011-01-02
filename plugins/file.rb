class FileIO <Plugin
  name :file
  description 'Plugin to read/write to files'

  def initialize(sender, s); end
  
  def commands
    {
      'cat' => [:cat, 1, {
        :permission => 'admin',
        :help => 'View a file',
        :usage => '/home/zynox/file' }],
      'write' => [:write, 2, {
        :permission => 'admin',
        :help => 'Write to a file',
        :usage => '/home/zynox/hello Hello world!' }],
      'append' => [:append, 2, {
        :permission => 'admin',
        :help => 'Add data to the end of a file',
        :usage => '/home/zynox/hello Another hello world!' }],
    }
  end
  
  def cat(e, file)
    begin
      File.read(File.expand_path(file))
    rescue
      "file not found or access denied"
    end
  end
  
  def write(e, file, data)
    begin
      f = File.open(File.expand_path(file), 'w')
      f.write(data)
      'data written'
    rescue
      'access denied'
    ensure
      f.close unless f.nil?
    end
  end
  
  def append(e, file, data)
    begin
      f = File.open(File.expand_path(file), 'a')
      f.write(data)
      'data written to end of file'
    rescue
      'access denied'
    ensure
      f.close unless f.nil?
    end
  end
end
