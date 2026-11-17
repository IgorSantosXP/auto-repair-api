class CreateMessagingTables < ActiveRecord::Migration[8.1]
  def change
    create_table :outbox_messages do |t|
      t.string   :message_id,   null: false
      t.string   :message_type, null: false
      t.string   :destination,  null: false
      t.jsonb    :body,         null: false
      t.datetime :published_at
      t.timestamps
    end
    add_index :outbox_messages, :message_id, unique: true
    add_index :outbox_messages, :id, where: "published_at IS NULL", name: "index_outbox_messages_pending"

    create_table :processed_messages do |t|
      t.string   :message_id, null: false
      t.datetime :created_at, null: false
    end
    add_index :processed_messages, :message_id, unique: true
  end
end
