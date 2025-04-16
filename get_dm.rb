require './lib_typetalk.rb'

output_dir = ARGV[0] || 'backup'
credential_file = ARGV[1] || 'credentials.json'

p output_dir
p credential_file

# アクセストークン取得
tt = TypeTalk.new(credential_file, output_dir)

# --- DMを取得して保存する ---
dms_json = tt.fetch_dm_topics()

output_dir = File.join(output_dir, "dm")
FileUtils.mkdir_p(output_dir)
p output_dir

if dms_json then
  dms_json['topics'].each_with_index do |dm, index|
    topic = dm['topic']
    topic_id = topic['id']
    topic_name = topic['name']
    puts "#{index+1}/#{dms_json['topics'].size} 📥 DM取得中: (ID: #{topic_id}) #{topic_name}"

    # メッセージ取得して保存
    messages_all = save_topic_messages(tt, topic_id, output_dir)
    posts = messages_all['posts']

    if messages_all
      posts = messages_all['posts']
      download_attachments(tt, messages_all, output_dir)
      download_accounts(posts, topic_id, output_dir)
    end
  end
end

puts "✅ メッセージ保存完了！ (保存先: #{output_dir})"

