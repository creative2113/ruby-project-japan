class FileCounter < ApplicationRecord

  def register(new_count)
    self.one_before_count = self.count
    self.count            = new_count
    self.save!
  end

  def same_count?(current_count)
    self.count == current_count.to_i
  end
end
