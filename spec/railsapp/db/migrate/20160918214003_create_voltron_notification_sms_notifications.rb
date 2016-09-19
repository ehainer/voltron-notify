class CreateVoltronNotificationSmsNotifications < ActiveRecord::Migration
  def change
    create_table :voltron_notification_sms_notifications do |t|
      t.string :to
      t.string :from
      t.text :message
      t.text :request_json
      t.text :response_json
      t.integer :notification_id
      t.string :status
      t.string :sid

      t.timestamps null: false
    end
  end
end
