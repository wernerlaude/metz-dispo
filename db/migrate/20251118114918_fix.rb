class Fix < ActiveRecord::Migration[8.0]
  def change
    execute "ALTER TABLE drivers ADD PRIMARY KEY (id);"
  end
end
