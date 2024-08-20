class Result < ApplicationRecord
  belongs_to :requested_url

  def update_single_url_ids(new_url_ids)
    update_array_attribute('single_url_ids', new_url_ids)
  end

  def update_candidate_urls(new_candidate_urls)
    update_array_attribute('candidate_crawl_urls', new_candidate_urls)
  end

  def take_out_candidate_urls(count)
    return [] if self.candidate_crawl_urls.blank?

    take_out_urls = []
    self.with_lock do
      urls = Json2.parse(self.candidate_crawl_urls)

      if urls.size > count
        take_out_urls = urls[0..count-1]
        leave_urls = urls[count..-1]
      else
        take_out_urls = urls
        leave_urls = nil
      end

      self.candidate_crawl_urls = leave_urls&.to_json
      self.save!
    end
    take_out_urls
  end

  def update_array_attribute(attribute_str, new_objects)
    return self.attributes[attribute_str] if new_objects.blank?

    objects = []
    self.with_lock do
      objects = Json2.parse(self.attributes[attribute_str])

      if objects.present?
        objects.concat(new_objects)
      else
        objects = new_objects
      end
      objects.uniq!

      self.update!(attribute_str => objects.to_json)
    end
    objects
  end
end
