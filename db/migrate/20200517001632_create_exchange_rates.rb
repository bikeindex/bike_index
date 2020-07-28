# frozen_string_literal: true

class CreateExchangeRates < ActiveRecord::Migration[5.2]
  def change
    create_table :exchange_rates do |t|
      t.string :from, null: false
      t.string :to, null: false
      t.float :rate, null: false

      t.index [:from, :to], unique: true

      t.timestamps
    end
  end
end
