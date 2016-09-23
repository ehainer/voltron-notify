class CreateVoltronNotifications < ActiveRecord::Migration
  def change
    create_table :voltron_notifications do |t|
      t.string :notifyable_type
      t.integer :notifyable_id

      t.timestamps null: false
    end
  end
end
