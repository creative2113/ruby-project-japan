class AddInvestigationCountToMonthlyHistories < ActiveRecord::Migration[6.1]
  def change
    add_column :monthly_histories, :simple_investigation_count, :integer, default: 0, after: :acquisition_count
  end
end
