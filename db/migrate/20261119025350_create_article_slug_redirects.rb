class CreateArticleSlugRedirects < ActiveRecord::Migration[7.1]
  def change
    create_table :article_slug_redirects do |t|
      t.references :account, null: false, index: true
      t.references :article, null: false, index: true
      t.string :slug, null: false

      t.timestamps
    end

    add_index :article_slug_redirects, :slug, unique: true
  end
end
