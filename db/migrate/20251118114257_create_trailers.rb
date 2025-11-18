class CreateTrailers < ActiveRecord::Migration[8.0]
  def change
    create_table :trailers, force: :cascade do |t|
      t.string :license_plate
      t.integer :art

      t.timestamps
    end
  end
end
