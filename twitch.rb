#!/usr/bin/env ruby
require 'open-uri'
require 'json'
require 'pry'

def token(channel)
  s = open("http://api.twitch.tv/api/channels/#{channel}/access_token", &:read)
  JSON.parse(s)
end
def uri(channel, token)
  encoded_token = URI.encode token["token"]  
  sig = token["sig"]  
  base = "http://usher.justin.tv/api/channel/hls/"  

  "#{base}#{channel}.m3u8?token=#{encoded_token}&sig=#{sig}&allow_source=true"
end

channel = ARGV[0]

open(uri(channel, token(channel)), &:read).display
