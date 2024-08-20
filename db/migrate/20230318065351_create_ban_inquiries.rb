class CreateBanInquiries < ActiveRecord::Migration[6.1]
  def change
    create_table :ban_inquiries do |t|
      t.string :mail, index: true

      t.timestamps
    end
  end
end
