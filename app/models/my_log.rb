class MyLog
  def initialize(file_name, dir_path: nil, rotate: true)
    @file_name = file_name
    @dir = dir_path || 'log'
    @rotate = rotate
  end

  def log(text)
    File.open(file_path, mode = "a") do |f|
      f.write(to_string(text) + "\n")
    end
  end

  def file_path
    file_name = @rotate ? "#{@file_name}_#{Time.zone.now.strftime("%Y%m%d")}" : @file_name
    "#{@dir}/#{file_name}.log"
  end

  def read
    f = File.open(file_path, "r")
    message = f.read
    f.close
    message
  end

  private

  def to_string(text)
    if text.class == String
      text
    elsif text.class == Array
      text.join("\n")
    else
      text.to_s
    end
  end
end
