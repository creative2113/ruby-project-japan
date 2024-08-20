# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email # Only if using reconfirmable

      ## Lockable
      t.integer  :failed_attempts, default: 0, null: false # Only if lock strategy is :failed_attempts
      t.string   :unlock_token # Only if unlock strategy is :email or :both
      t.datetime :locked_at

      t.string   :company_name
      t.string   :language
      t.boolean  :terms_of_service
      t.integer  :search_count,               default: 0
      t.integer  :last_search_count,          default: 0
      t.date     :latest_access_date
      t.integer  :monthly_search_count,       default: 0
      t.integer  :last_monthly_search_count,  default: 0
      t.integer  :request_count,              default: 0
      t.integer  :last_request_count,         default: 0
      t.date     :last_request_date
      t.integer  :monthly_request_count,      default: 0
      t.integer  :last_monthly_request_count, default: 0
      t.bigint   :setting_id
      t.bigint   :referrer_id

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token,   unique: true
    add_index :users, :unlock_token,         unique: true
  end
end
