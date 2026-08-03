# frozen_string_literal: true

class CreateFederatedPortals < ActiveRecord::Migration[7.0]
  def change
    create_table :federated_portals do |t|
      t.string :portal_key, null: false
      t.string :name, null: false
      t.string :ui
      t.string :api
      t.string :color
      t.string :light_color
      t.text :encrypted_apikey

      t.timestamps
    end

    add_index :federated_portals, :portal_key, unique: true
  end
end
