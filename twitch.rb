#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'pry'
require 'thor'

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

class Twitch < Thor
  desc "stream CHANNEL", "output an m3u8 suitable for VLC"
  def stream(channel)
    uri = stream_uri(channel)
    m3u8 = Net::HTTP.get(uri)
    m3u8.display
  end
end

Twitch.start(ARGV)
