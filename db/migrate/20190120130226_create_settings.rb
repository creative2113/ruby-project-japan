class CreateSettings < ActiveRecord::Migration[5.2]
  def change
    create_table :settings do |t|
      t.text :output_formats # エクセルの出力形式を変更可能、配列とハッシュの組み合わせ、出力順序も調整する
      t.text :search_words   # クロール時に選択するワード追加

      t.timestamps
    end
  end
end
