class Preference < ApplicationRecord
  belongs_to :user

  class << self

    # 実行したらどこかで削除する
    def make_preferences_for_all_user
      User.all.each do |user|
        if user.preferences.nil?
          preferences = user.build_preferences

          begin
            preferences.save!
          rescue => e
            puts "Error!!! user = #{user.id}"
          end
        end
      end
      true
    end
  end
end
