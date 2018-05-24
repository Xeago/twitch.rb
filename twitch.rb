#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'pry'
require 'thor'
require 'twitch-api'
require 'm3u8'
require 'benchmark'
require 'concurrent'
require 'fileutils'
require 'tempfile'


def token_uri(channel)
  URI.parse("http://api.twitch.tv/api/channels/#{channel}/access_token")
end
def token(channel)
  s = Net::HTTP.start('api.twitch.tv', use_ssl: true) do |http|
     http.get(token_uri(channel), {'Client-ID' => 'jzkbprff40iqj646a697cyrvl0zt2m6'})
  end
  JSON.parse(s.body)
end

def stream_uri(channel)
  base = "http://usher.justin.tv/api/channel/hls/"
  channel_streamer = File.basename channel
  token = token(channel_streamer)
  uri = URI("#{base}#{channel_streamer}")
  uri.query = URI.encode_www_form({
    sig: token["sig"],
    token: token["token"],
    allow_source: true,
  })
  uri
end

def to_json(obj)
  JSON.dump(Hash[obj.instance_variables.map { |name| [name, obj.instance_variable_get(name)] }])
end

class TwitchRb < Thor
  desc "stream CHANNEL", "output an m3u8 suitable for VLC"
  def stream(channel)
    uri = stream_uri(channel)
    m3u8 = Net::HTTP.get(uri)
    m3u8.display
  end

  desc "archive CHANNEL [LIMIT]", "archive the most recent stream"
  def archive(channel, limit=3)
    archive_path = (ENV['ARCHIVE'] or "archive")
    limit = [limit.to_i, 100].min
    client = Twitch::Client.new client_id: (ENV['CLIENT_ID'] or raise "Set CLIENT_ID")
    user_response = client.get_users(login: channel)
    raise "Streamer not found: #{channel}" unless user_response.data.length == 1
    streamer = user_response.data.first
    video_response = client.get_videos(user_id: streamer.id, first: limit)
    raise "No videos found :<" unless video_response.data.length >= 1
    pool = Concurrent::ThreadPoolExecutor.new(
      :min_threads => [2, Concurrent.processor_count].max,
      :max_threads => Concurrent.processor_count * 4,
      :max_queue   => 0,
    )
    video_response.data.reverse.each do |video|
      extractor = /(?<uuid>[^ _\/]+)_(?<user_id>[^ _\/]+)_(?<numbers>[^ \/]+)/
      uuid, user_id, numbers  = extractor.match(video.thumbnail_url).captures
      base_uri = "https://vod-pop-secure.twitch.tv/#{uuid}_#{user_id}_#{numbers}/chunked/"
      index_uri = URI(base_uri + "index-dvr.m3u8")
      puts({index: index_uri})
      m3u8 = Net::HTTP.get(index_uri)
      streamer_root = "#{archive_path}/#{user_id}/"
      prefix = "#{streamer_root}/#{uuid}/#{numbers}/"
      FileUtils::mkdir_p prefix

      m3u8_path = prefix + "index.m3u8"
      if File.exist? m3u8_path
        next if m3u8 == File.open(m3u8_path).read
      end

      playlist = M3u8::Playlist.read(m3u8)
      next if playlist.items.empty?
      chunks = playlist.items.map(&:segment)
      extension = File.extname(chunks[0])
      have = Dir[prefix + '*' + extension].map { |f| File.basename f }
      needed = chunks - have
      download_uris = needed.map {|e| [e, URI(base_uri + e)]}
      download_uris.each_with_index do |(name, download), i|
        pool.post do
          Net::HTTP.start(index_uri.host, index_uri.port, :use_ssl => index_uri.scheme == 'https') do |http|
            chunk_response = http.get download.path
            tmp = Tempfile.new(name)
            File.open(tmp, 'w+') do |file|
              file.write(chunk_response.body)
            end
            FileUtils.ln(tmp.path, prefix + name)
            tmp.close!
            puts "#{name} (#{pool.scheduled_task_count}/#{needed.size})"
          end
        end
      end
      meta_files = {
          streamer_root + 'streamer.json' => to_json(streamer),
          prefix + 'video.json' => to_json(video),
          m3u8_path => m3u8,
      }
      meta_files.each do |path, contents|
        File.open path, 'w+' do |f|
          f.write contents
        end
      end
    end
    pool.shutdown
    pool.wait_for_termination
    vods = Dir[archive_path + '/*/*/*/video.json'].map do |v|
      path = File.dirname(v)
      playable = File.exist?(path + "/index.m3u8") ? true : false
      {
        video: path[archive_path.length+1..v.length],
        playable: playable
      }
    end.group_by do |vod|
      user_name, uuid, numbers = vod[:video].match(
        /#{Regexp.quote(archive_path)}\/(?<user_id>[^ _\/]+)\/(?<uuid>[^ _\/]+)\/(?<numbers>[^ \/]+)/).captures;
      user_name
    end
    File.open(archive_path + '/vods.json', 'w+')  do |file|
      file.write(JSON.dump(vods))
    end
  end
end

TwitchRb.start(ARGV)
