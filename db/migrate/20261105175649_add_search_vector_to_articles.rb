class AddSearchVectorToArticles < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  # Precomputes the weighted document Article.text_search ranks against, so the GIN index can serve it.
  # f_unaccent is the IMMUTABLE wrapper around unaccent that a generated column requires.
  SEARCH_VECTOR = <<~SQL.squish.freeze
    setweight(to_tsvector('simple', f_unaccent(coalesce(title, ''))), 'A') ||
    setweight(to_tsvector('simple', f_unaccent(coalesce(description, ''))), 'B') ||
    setweight(to_tsvector('simple', f_unaccent(coalesce(content, ''))), 'C')
  SQL

  def change
    add_column :articles, :search_vector, :virtual, type: :tsvector, as: SEARCH_VECTOR, stored: true
    add_index :articles, :search_vector, using: :gin, algorithm: :concurrently
  end
end
