class CreateConsents < ActiveRecord::Migration[8.1]
  def change
    create_table :consents do |t|
      t.string :consent_id
      t.string :status
      t.date :valid_until

      t.timestamps
    end
  end
end
