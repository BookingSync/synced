class AddTranslationsToLocations < ActiveRecord::Migration
  def up
    Location.create_translation_table! name: :string
  end

  def down
    Location.drop_translation_table
  end
end
