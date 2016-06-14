#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'pry'
require 'thor'

def token_uri(channel)
  URI.parse("http://api.twitch.tv/api/channels/#{channel}/access_token")
end
def token(channel)
  s = Net::HTTP.get(token_uri(channel))
  JSON.parse(s)
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

  desc "vlc CHANNEL", "open the m3u8 stream in VLC (osx)"
  def vlc(channel)
    uri = stream_uri(channel)
    m3u8 = Net::HTTP.get uri
    vlc = IO.popen ['/Applications/VLC.app/Contents/MacOS/VLC', '-q', '-'], 'w'
    pid = vlc.pid
    vlc.write m3u8
#    Signal.trap("INT") { Process.kill 15, pid; exit }
    vlc.flush
  end

  desc "list DIRECTORY", "search for streams in DIRECTORY"
  def list(*directory)
    uri = URI("https://api.twitch.tv/kraken/streams")
    game = directory.join ' '
    uri.query = URI.encode_www_form({game: game})
    streams = JSON.parse(uri.open(&:read))
    r = streams['streams'].map {|e| e['channel'] }.map {|c| [c['display_name'], c['status']]}
    r.each {|e| puts "#{e[0]} #{e[1]}" }
  end
end

Twitch.start(ARGV)
