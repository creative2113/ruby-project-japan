class CreateNotices < ActiveRecord::Migration[5.2]
  def change
    create_table :notices do |t|
      t.string   :subject
      t.text     :body
      t.boolean  :display
      t.datetime :opened_at

      t.timestamps
    end
  end
end
