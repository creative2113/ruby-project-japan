class AnalysisData::Base
  class << self
    def create
      config = ListCrawlConfig.find_by_domain(domain)
      if config.present?
        config.update!(analysis_result: customize.to_json)
      else
        ListCrawlConfig.create!(domain: domain, domain_path: path, analysis_result: customize.to_json, class_name: self.to_s, process_result: enable_process_result)
      end
    end

    def find
      ListCrawlConfig.find_by_domain(domain)
    end

    def ban_pathes; []; end

    def ban_pathes_alert_message; nil; end
  end
end
