#require 'faraday'
require 'json'
require 'set'
require 'net/http'
require 'uri'
require 'fileutils'
require 'securerandom'
require 'open-uri'

# グローバル変数でトークンを管理
$access_token = nil
$space_key = nil

class TypeTalk
  attr_accessor :access_token, :space_key
  def initialize(credentials_file, backup_base_dir)
    @credentials_file = credentials_file
    @access_token = nil
    @space_key = nil
    @backup_base_dir = backup_base_dir

    get_accesstoken()
  end

  def get_accesstoken()
  #  credentials_file = 'typetalk_credentials.json'
    unless File.exist?(@credentials_file)
      puts "❌ 認証情報ファイル #{@credentials_file} が見つかりません"
      exit 1
    end
  
    credentials = JSON.parse(File.read(@credentials_file))
    client_id = credentials['client_id']
    client_secret = credentials['client_secret']
    space_key = credentials['spacekey']

## Faraday    
#    response = Faraday.post('https://typetalk.com/oauth2/access_token') do |req|
#      req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
#      req.body = URI.encode_www_form(
#        client_id: client_id,
#        client_secret: client_secret,
#        grant_type: 'client_credentials',
#        scope: 'my topic.read'
#      )
#    end
#    
#    if response.success?
#      json = JSON.parse(response.body)
#      @access_token = json['access_token']
#      @space_key = space_key
#      puts "✅ アクセストークン取得成功！（更新）"
#    else
#      puts "❌ アクセストークン取得失敗: #{response.status}"
#      puts response.body
#      exit 1
#    end
## net/http利用
    uri = URI.parse('https://typetalk.com/oauth2/access_token')
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    request.set_form_data(
      client_id: client_id,
      client_secret: client_secret,
      grant_type: 'client_credentials',
      scope: 'my topic.read'
    )
  
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
  
    if response.is_a?(Net::HTTPSuccess)
      json = JSON.parse(response.body)
      @access_token = json['access_token']
      @space_key = space_key
      puts "✅ アクセストークン取得成功！（Net::HTTP版）"
      return [@access_token, @space_key]
    else
      puts "❌ アクセストークン取得失敗: #{response.code}"
      puts response.body
      exit 1
    end
 
    return ([@access_token, @space_key])
  end
  
  # --- 関数：トピック一覧を取得する ---
  def fetch_topics()
#    response = Faraday.get('https://typetalk.com/api/v3/topics') do |req|
#      req.headers['Authorization'] = "Bearer #{@access_token}"
#      req.params['spaceKey'] = @space_key
#    end
#  
#    unless response.success?
#      puts "❌ トピック一覧取得失敗: #{response.status}"
#      exit 1
#    end
    uri = URI.parse("https://typetalk.com/api/v3/topics?spaceKey=#{@space_key}")
  
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@access_token}"
  
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
  
    response = http.start { |h| h.request(request) }
  
    if response.code.to_i == 200
      puts "✅ トピック一覧取得成功！"
      return JSON.parse(response.body)
    else
      puts "❌ トピック一覧取得失敗: #{response.code}"
      puts response.body
      return nil
    end
  
    JSON.parse(response.body)
  end

  # --- 関数：ダイレクトメッセージ一覧を取得する ---
  def fetch_dm_topics()
    uri = URI.parse('https://typetalk.com/api/v2/messages')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    request['Authorization'] = "Bearer #{@access_token}"

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      puts "❌ DM一覧取得失敗: #{response.code}"
      return nil
    end

    JSON.parse(response.body)
  end

  def get_topic_messages(topic_id, from_id = 0)
    all_messages = []
    json = Hash.new
    retries = 0
  
    loop do
## Faraday
#      response = Faraday.get("https://typetalk.com/api/v1/topics/#{topic_id}") do |req|
#        req.headers['Authorization'] = "Bearer #{@access_token}"
#        req.params['count'] = 200
#        req.params['direction'] = "forward"
#        req.params['from'] = from_id if from_id
#      end
#  
#      if response.status == 401
#        retries += 1
#        if retries == 1
#          puts "⚠️ 401エラー発生。アクセストークンを再取得してリトライします..."
#          get_accesstoken() # トークン再取得
#          next
#        elsif retries <= 3
#          puts "⚠️ 401エラー。60秒待ってリトライします...(リトライ#{retries}回目)"
#          sleep(60)
#          next
#        else
#          puts "❌ 401エラーが続いたので諦めます。(Topic ID: #{topic_id})"
#          return nil
#        end
#      elsif !response.success?
#        puts "⚠️ メッセージ取得失敗: #{response.status} (Topic ID: #{topic_id})"
#        return nil
#      end

## net/http
      uri = URI.parse("https://typetalk.com/api/v1/topics/#{topic_id}?count=200&direction=forward")
      uri.query += "&from=#{from_id}" if from_id && from_id > 0
  
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{access_token}"
  
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
  
      if response.code.to_i == 401
        retries += 1
        if retries <= 3
          puts "⚠️ 401エラー、60秒待ってリトライします...(リトライ#{retries}回目)"
          sleep(60)
          get_accesstoken() # トークン再取得
          next
        else
          puts "❌ 401エラーが続いたので諦めます...(Topic ID: #{topic_id})"
          return nil
        end
      elsif !response.is_a?(Net::HTTPSuccess)
        puts "⚠️ メッセージ取得失敗: #{response.code} (Topic ID: #{topic_id})"
        return nil
      end
 
      retries = 0  # 成功したらリトライカウントをリセット
  
      json = JSON.parse(response.body)
      messages = json['posts'] || []
      break if messages.empty?
  
      all_messages.concat(messages)
      from_id = messages.last['id']
  
      puts "🔄 さらに続くメッセージを取得中... (最新 fromId: #{from_id}) (#{all_messages.size})"
    end
  
    json['posts'] = all_messages
    return json
  end

  
  def fetch_dm_topics()
    uri = URI.parse("https://typetalk.com/api/v2/messages?spaceKey=#{@space_key}")
  
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@access_token}"
  
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
  
    response = http.start { |h| h.request(request) }
  
    if response.code.to_i == 200
      puts "✅ DM一覧取得成功！"
      return JSON.parse(response.body)
    else
      puts "❌ DM一覧取得失敗: #{response.code}"
      puts response.body
      return nil
    end
  end

end
  
def print_messages(messages)
  messages.each_with_index do |message, index|
    puts("#{index} : [#{message['id']}] : #{message['message']}")
  end
end

def _get_all_messages(typetalk_obj, topic_id, from_id = 0)
  all_messages = []
  json = Hash.new
  retries = 0

  loop do
## Farady
#    response = Faraday.get("https://typetalk.com/api/v1/topics/#{topic_id}") do |req|
#      req.headers['Authorization'] = "Bearer #{$access_token}"
#      req.params['count'] = 200
#      req.params['direction'] = "forward"
#      req.params['from'] = from_id if from_id
#    end
#
#    if response.status == 401
#      retries += 1
#      if retries == 1
#        puts "⚠️ 401エラー発生。アクセストークンを再取得してリトライします..."
#        typetalk_obj.get_accesstoken() # トークン再取得
#        next
#      elsif retries <= 3
#        puts "⚠️ 401エラー。60秒待ってリトライします...(リトライ#{retries}回目)"
#        sleep(60)
#        next
#      else
#        puts "❌ 401エラーが続いたので諦めます。(Topic ID: #{topic_id})"
#        return nil
#      end
#    elsif !response.success?
#      puts "⚠️ メッセージ取得失敗: #{response.status} (Topic ID: #{topic_id})"
#      return nil
#    end

    params = { count: 200, direction: "forward" }
    params[:from] = from_id if from_id > 0

    uri = URI.parse("https://typetalk.com/api/v1/topics/#{topic_id}")
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@access_token}"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    response = http.start { |h| h.request(request) }

    if response.code.to_i == 401
      retries += 1
      if retries == 1
        puts "⚠️ 401エラー発生。アクセストークンを再取得してリトライします..."
        get_accesstoken()
        typetalk_obj.get_accesstoken() # トークン再取得
        next
      elsif retries <= 3
        puts "⚠️ 401エラー。60秒待ってリトライします...(リトライ#{retries}回目)"
        sleep(60)
        typetalk_obj.get_accesstoken() # トークン再取得
        next
      else
        puts "❌ 401エラーが続いたので諦めます。(Topic ID: #{topic_id})"
        return nil
      end
    elsif response.code.to_i != 200
      puts "⚠️ メッセージ取得失敗: #{response.code} (Topic ID: #{topic_id})"
      return nil
    end

    retries = 0  # 成功したらリトライカウントをリセット

    json = JSON.parse(response.body)
    messages = json['posts'] || []
    break if messages.empty?

    all_messages.concat(messages)
    from_id = messages.last['id']

    puts "🔄 さらに続くメッセージを取得中... (最新 fromId: #{from_id}) (#{all_messages.size})"
  end

  json['posts'] = all_messages
  return json
end



def save_topic_messages(typetalk_obj, topic_id, backup_base_dir)
  backup_dir = File.join(backup_base_dir, topic_id.to_s)
  messages_file = File.join(backup_dir, 'messages.json')
  FileUtils.mkdir_p(backup_dir)

  # すでに保存済みのmessages.jsonを読み込む
  existing_messages = []
  if File.exist?(messages_file)
    existing_json = JSON.parse(File.read(messages_file))
    existing_messages = existing_json['posts'] || []
    puts "📂 既存メッセージ読み込み: #{existing_messages.size} 件"
  else
    puts "📂 新規メッセージ取得開始"
  end

  # 既存メッセージの最大IDを取得
  from_id = if existing_messages.empty?
    0
  else
    existing_messages.map { |msg| msg['id'] }.max
  end

  # 新しいメッセージを取得
  new_json = typetalk_obj.get_topic_messages(topic_id, from_id)
  return unless new_json

  new_messages = new_json['posts'] || []

  if new_messages.empty?
    puts "✅ 追加メッセージなし (from_id=#{from_id})"
  else
    puts "✅ 新規メッセージ取得: #{new_messages.size} 件"
  end

  # 既存メッセージ + 新メッセージ をまとめる
  all_messages = existing_messages + new_messages
  all_messages.uniq! { |msg| msg['id'] }  # 重複防止

  # 保存
  output_json = new_json
  output_json['posts'] = all_messages
  File.write(messages_file, JSON.pretty_generate(output_json))
  puts "💾 メッセージ保存完了: #{messages_file} (合計 #{all_messages.size} 件)"

  return output_json
end




def download_attachments(typetalk_obj, messages, save_base_dir)
  posts = messages['posts']
  posts.each_with_index do |post, index|
    next unless post['attachments'] && !post['attachments'].empty?

    post_id = post['id']
    topic_id = post['topicId']
    post['attachments'].each_with_index do |att, index2|
      attachment_info = att['attachment']
      api_url = att['apiUrl']
      filename = attachment_info['fileName']

      # 保存先ディレクトリを作成
      save_dir = File.join(save_base_dir, topic_id.to_s, 'attachments', post_id.to_s, (index2+1).to_s)
      FileUtils.mkdir_p(save_dir)

      save_path = File.join(save_dir, filename)

      # ファイルが既に存在すればスキップ
      if File.exist?(save_path)
        puts "✅ すでに存在: #{save_path}"
        next
      end

      # 添付ファイルをダウンロード
      retries = 0
      loop do
        puts "⬇️ ダウンロード中: #{index+1}/#{posts.size} : #{post_id} #{api_url} → #{save_path}"

## Faraday 
#        response = Faraday.get(api_url) do |req|
#          req.headers['Authorization'] = "Bearer #{typetalk_obj.access_token}"
#        end
# 
#        if response.status == 401
#          retries += 1
#          if retries == 1
#            puts "⚠️ 401エラー発生。アクセストークンを再取得してリトライします..."
#            typetalk_obj.get_accesstoken() # トークン再取得
#            next
#          elsif retries <= 3
#            puts "⚠️ 401エラー。60秒待ってリトライします...(リトライ#{retries}回目)"
#            sleep(60)
#            next
#          else
#            puts "❌ 401エラーが続いたので諦めます。(Topic ID: #{topic_id})"
#            break
#          end
#        end
#    
#        if response.success?
#          begin
#            File.binwrite(save_path, response.body)
#          rescue Errno::EINVAL, Errno::EILSEQ => e
#            puts "⚠️ ファイル名エラー発生 → ランダムファイル名に変更します！"
#          
#            # ファイル名をランダムにする
#            new_filename = "invalid_filename_#{SecureRandom.hex(8)}"
#            ext = File.extname(filename)
#            new_filename += ext unless ext.empty?
#            save_path = File.join(save_dir, new_filename)
#          
#            # もう一度保存を試みる
#            File.binwrite(save_path, response.body)
#          
#            puts "✅ リカバリ保存成功: #{new_filename}"
#          
#            # ❗ postsの中身も書き換える
#            # このpost（投稿）内のattachmentsを探して、ファイル名を更新
#            post = posts[index]
#            p post
#            post['attachments'].each do |attachment|
#              if attachment['attachment']['fileName'] == filename
#                attachment['attachment']['fileName'] = new_filename
#
#                posts_file = File.join(save_base_dir, topic_id.to_s, 'messages.json')
#                p posts_file
#                File.write(posts_file, JSON.pretty_generate(messages))
#                puts "💾 posts 更新保存完了！"
#              end
#            end
#            puts "✅ メッセージ中のファイル名変更成功: #{new_filename} #{post_id}"
#            p post
#          end
#
#          puts "✅ ダウンロード成功: #{filename}"
#          break
#        else
#          puts "❌ ダウンロード失敗: #{response.status} (#{api_url})"
#          break
#        end


        uri = URI.parse(api_url)
        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = "Bearer #{typetalk_obj.access_token}"

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        response = http.start { |h| h.request(request) }

        if response.code.to_i == 401
          retries += 1
          if retries <= 1
            puts "⚠️ 401エラー発生。アクセストークンを再取得してリトライします..."
            sleep(60)
            typetalk_obj.get_accesstoken()
            next
          else
            puts "❌ 401エラーが続いたので諦めます。(Topic ID: #{topic_id})"
            break
          end
        end

        if response.code.to_i == 200
          begin
            File.binwrite(save_path, response.body)
          rescue Errno::EINVAL, Errno::EILSEQ => e
            puts "⚠️ ファイル名エラー発生 → ランダムファイル名に変更します！"

            new_filename = "invalid_filename_#{SecureRandom.hex(8)}"
            ext = File.extname(filename)
            new_filename += ext unless ext.empty?
            save_path = File.join(save_dir, new_filename)

            File.binwrite(save_path, response.body)
            puts "✅ リカバリ保存成功: #{new_filename}"

            post = posts[index]
            post['attachments'].each do |attachment|
              if attachment['attachment']['fileName'] == filename
                attachment['attachment']['fileName'] = new_filename
                posts_file = File.join(save_base_dir, topic_id.to_s, 'messages.json')
                File.write(posts_file, JSON.pretty_generate(messages))
                puts "💾 posts 更新保存完了！"
              end
            end
          end

          puts "✅ ダウンロード成功: #{filename}"
          break
        else
          puts "❌ ダウンロード失敗: #{response.code} (#{api_url})"
          break
        end

      end

    end
  end

end



def download_accounts(posts, topic_id, backup_dir)
  icons_dir = File.join(backup_dir, 'icons')
  icons_dir2 = File.join(backup_dir, topic_id.to_s, 'icons') # トピック内
  accounts_file = File.join(backup_dir, 'accounts.json')
  members_file = File.join(backup_dir, topic_id.to_s, 'members.json') # トピック内に保存

  FileUtils.mkdir_p(icons_dir)
  FileUtils.mkdir_p(icons_dir2)

  # 既存のaccounts.jsonを読む
  accounts = if File.exist?(accounts_file)
    JSON.parse(File.read(accounts_file))
  else
    []
  end
  members_index = Hash.new # 対象トピック内のユーザー一覧

  # ユーザーIDで重複防止
  accounts_index = accounts.map { |acc| [acc['id'], acc] }.to_h
  # ❗ 404が出たIDを記録
  not_found_icon_ids = Set.new

  posts.each do |post|
    account = post['account']
    next unless account

    account_data = {
      'id' => account['id'],
      'name' => account['name'],
      'fullName' => account['fullName'],
      'imageUrl' => account['imageUrl'],
      'createdAt' => account['createdAt'],
      'updatedAt' => account['updatedAt']
    }

    # accounts_indexに追加または上書き
    accounts_index[account['id']] = account_data
    members_index[account['id']] = account_data

    # アイコン画像を保存（既に保存されていなければ）
    next if not_found_icon_ids.include?(account['id'])  # 404が起きたIDならスキップ
    icon_path1 = File.join(icons_dir, "#{account['id']}.png")
    icon_path2 = File.join(icons_dir2, "#{account['id']}.png")
    unless File.exist?(icon_path1) || File.exist?(icon_path2)
      begin
        URI.open(account['imageUrl']) do |image|
          File.binwrite(icon_path1, image.read)
          File.binwrite(icon_path2, image.read)
        end
        puts "✅ アイコン画像保存: #{icon_path1} #{icon_path2}"
      rescue OpenURI::HTTPError => e
        if e.message.include?('404')
          puts "⚠️ 404エラー (ID: #{account['id']}) : アイコン存在しないため今後スキップ"
          not_found_icon_ids << account['id']
        else
          puts "⚠️ アイコン保存失敗 (ID: #{account['id']}): #{e.message}"
        end
      rescue => e
        puts "⚠️ アイコン保存 その他エラー (ID: #{account['id']}): #{e.message}"
      end
    end

  end

  # 最後にaccounts.jsonを保存
  accounts = accounts_index.values
  File.write(accounts_file, JSON.pretty_generate(accounts))
  puts "✅ accounts.json 保存完了！ (#{accounts.size}件)"

  # トピック内の登場メンバーのみ members.json をトピックのディレクトリへ保存
  members = members_index.values
  File.write(members_file, JSON.pretty_generate(members))
  puts "✅ members.json 保存完了！ (#{members.size}件)"

end

