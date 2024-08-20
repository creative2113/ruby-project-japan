class AddReferralReasonToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :referral_reason, :integer, default: nil, after: :referrer_id
  end
end
