require 'fileutils'
require './lib_typetalk.rb'

# --- メイン処理 ---
output_dir = ARGV[0] || 'backup'
credential_file = ARGV[1] || 'credentials.json'

p output_dir
p credential_file

# アクセストークン取得
tt = TypeTalk.new(credential_file, output_dir)

# トピック一覧取得
topics_json = tt.fetch_topics()

# 保存先ディレクトリ
FileUtils.mkdir_p(output_dir)

# 各トピックのメッセージ取得
topics_json['topics'].each_with_index do |t, index|
#  break if index >= 1  # 打ち切り

  topic = t['topic']
  topic_id = topic['id']
  topic_name = topic['name']
#  topic_id = 434436
#  topic_name = "202411_縁日音楽で伝えるあなたの作品の素晴らしさ"

  puts "#{index+1}/#{topics_json['topics'].size} 📥 メッセージ取得中: #{topic_name} (ID: #{topic_id})"

  # メッセージ取得して保存
  messages_all = save_topic_messages(tt, topic_id, output_dir)

  if messages_all
    posts = messages_all['posts']
    download_attachments(tt, messages_all, output_dir)
    download_accounts(posts, topic_id, output_dir)
  end

end

puts "✅ メッセージ保存完了！ (保存先: #{output_dir})"

