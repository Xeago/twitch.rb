#!/usr/bin/env ruby
require 'open-uri'
require 'json'
require 'pry'
require 'thor'

def token(channel)
  s = open("http://api.twitch.tv/api/channels/#{channel}/access_token", &:read)
  JSON.parse(s)
end

def uri(channel, token)
  base = "http://usher.justin.tv/api/channel/hls/"
  uri = URI("#{base}#{channel}")
  uri.query = URI.encode_www_form({
    sig: token["sig"],
    token: token["token"],
    allow_source: true,
  })
  uri.to_s
end

class Twitch < Thor
  desc "stream CHANNEL", "output an m3u8 suitable for VLC"
  def stream(channel)
    open(uri(channel, token(channel)), &:read).display 
  end
end

Twitch.start(ARGV)
