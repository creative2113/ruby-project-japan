class CreateInquiries < ActiveRecord::Migration[5.2]
  def change
    create_table :inquiries do |t|
      t.string  :name
      t.string  :mail
      t.string  :title
      t.text    :body
      t.string  :genre
      t.boolean :close
      t.bigint  :user_id

      t.timestamps
    end
  end
end
