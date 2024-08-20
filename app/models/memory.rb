require "open3"

class Memory
  class << self
    def current
      if Rails.env.production? || Rails.env.dev?
        linux_memory.split("\n")[1].split(' ')[6].to_i
      else
        mac_memory.split(',')[1].split(' unused')[0].to_i * 1000
      end
    end

    def current_free
      if Rails.env.production? || Rails.env.dev?
        linux_memory.split("\n")[1].split(' ')[3].to_i
      else
        mac_memory.split(',')[1].split(' unused')[0].to_i * 1000
      end
    end

    def free_and_available
      if Rails.env.production? || Rails.env.dev?
        res = linux_memory.split("\n")[1]

        "[Free #{res.split(' ')[3]} M] [Available: #{res.split(' ')[6]} M]"
      else
        mac_memory.split(',')[1].split(' unused')[0].to_i * 1000
      end
    end

    def all
      if Rails.env.production? || Rails.env.dev?
        linux_memory
      else
        mac_memory
      end
    end

    def average(count:, interval:)
      arr = []
      arr << current
      sleep interval
      (count - 1).times do |i|
        sleep interval
        arr << current
      end
      arr.compact!
      arr.sum.fdiv(arr.length)
    end

    private

    def linux_memory
      stdout, stderr, status = Open3.capture3("free -mt")
      unless status.success?
        nil
      end
       stdout
    end

    def mac_memory
      stdout, stderr, status = Open3.capture3("top -l 1 -s 0 | grep PhysMem")
      unless status.success?
        nil
      end
       stdout
    end
  end
end
