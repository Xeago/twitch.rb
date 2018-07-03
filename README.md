# Twitch.rb
Simple twitch client displaying and archiving a playlist for a livestream.

## Usage
```
  twitch.rb stream CHANNEL           # output an m3u8 suitable for most media players
  twitch.rb archive CHANNEL [LIMIT]  # archive the most recent streams
```

## Installation
- Clone the repository
- `gem install concurrent-ruby thor pry twitch-api m3u8`
- `./twitch.rb help`

## Archiving
During a livestream, Twitch automatically populates it's archive with an update frequency of roughly 5 minutes. The archiver will catch up to Twitch's archive on each run. Running the archiver periodically ensures gapless transitions between restarts of streams. A certain kind fellow has written a [front-end].

## Known Issues
The archiver writes the meta files before each part of the playlist is downloaded and when nothing is downloaded at all. This has two effects:
- For a short duration the meta files thus reference non-existing objects. This is not a problem in regular operations as the time to catch up is usually less than the length of even a single chunk. This means it is essentially invisible to clients. Were this to use [promises] over manually managing a tasks in a threadpool.
- Modification times are nolonger indicative. There is however a suitable time in the meta file `video.json`. The lack of mtime (or ctime) makes deletions a bit of a nuisance. As `find archive -mtime +20 -delete` is unsuitable limiting storage space should probably be integrated in the archive command.

[front-end]: https://github.com/aquila12/browsebirb
[promises]: https://github.com/ruby-concurrency/concurrent-ruby/blob/master/doc/promises.out.md#asynchronous-task
