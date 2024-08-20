class Tasks::VirusCheck

  VIRUS_DIR = Rails.application.credentials.virus_check[:directory]
  LOG_PATH  = Rails.application.credentials.virus_check[:log]

  class << self

    def execute
      write_log(LOG_PATH, "VirusCheck Execute  #{Time.zone.now}")

      delete_virus

      get_all_directories('/*').each do |path|
        fc  = FileCounter.find_or_create_by(directory_path: path)
        cnt = get_file_count(path)

        write_log(LOG_PATH, "#{path}  CNT => #{cnt}  :  Before => #{fc.count}")

        unless fc.same_count?(cnt)
          fc.register(cnt)

          clamdscan(path)

          delete_virus
        end
      end
    rescue => e
      Lograge.job_logging('Tasks', 'error', 'VirusCheck', 'execute', { issue: e, err_msg: e.message, backtrace: e.backtrace })
    end

    def delete_virus
      write_log(LOG_PATH, "ls #{VIRUS_DIR} => #{get_all_files(VIRUS_DIR + '/*')}")

      if get_all_files(VIRUS_DIR + '/*').count > 0
        dummy        = 'dummy_virus.csv'
        fixture_path = Rails.root.join('spec', 'fixtures', dummy)
        `sudo mv #{VIRUS_DIR}/#{dummy} #{fixture_path}`

        `sudo rm #{VIRUS_DIR}/*`
      end
    end

    private

    def get_all_directories(path)
      res = []
      get_all_files_and_directories(path).each do |f|
        res << f if FileTest::directory?(f)
      end
      res
    end

    def get_all_files(path)
      res = []
      get_all_files_and_directories(path).each do |f|
        res << f unless FileTest::directory?(f)
      end
      res
    end

    def get_all_files_and_directories(path)
      Dir.glob(path, File::FNM_DOTMATCH).reject{|x| x =~ /\.$/}
    end

    def get_file_count(path)
      `sudo find #{path}/* -type f | wc -l`.strip.to_i
    end

    def clamdscan(path)
      `sudo clamdscan #{path} --move=#{VIRUS_DIR} -l #{LOG_PATH}`
    end

    def clamdscan_each_files(path)
      get_all_files(path + '/*').each do |file|
        `sudo clamdscan #{file} --move=#{VIRUS_DIR} -l #{LOG_PATH}`
      end
    end

    def write_log(path, text)
      File.open(path, 'a') do |f|
        f.puts(text)
      end
    end
  end
end
