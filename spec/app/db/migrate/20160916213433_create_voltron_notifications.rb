class CreateVoltronNotifications < ActiveRecord::Migration
	def change
		create_table :voltron_notifications do |t|
			t.string :notifyable_type
			t.integer :notifyable_id
			t.string :to_phone
			t.string :to_email
			t.column :request, :json
			t.column :response, :json

			t.timestamps null: false
		end
	end
end
