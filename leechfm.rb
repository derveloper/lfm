require 'rubygems'
require 'net/http'
require 'uri'
require 'md5'
require 'xspf'
require 'id3lib'
require 'ftools'


module LeechFM
  
  class Station
    
    def initialize(username, password)
      puts "logging in as #{username}"
      password = MD5.hexdigest(password)
      handshakeUri = "http://ws.audioscrobbler.com/radio/handshake.php?version=1.5.1&platform=win32&username=#{username}&passwordmd5=#{password}&language=de&player=LFM"
      handshakeUri = URI.parse(handshakeUri)
      @handshakeResponse = Net::HTTP.get handshakeUri
    end
    
    def session
      /^session=(.*)$/.match(@handshakeResponse)[1]
    end
    
    def base_path
      /^base_path=(.*)$/.match(@handshakeResponse)[1]
    end
    
    def base_url
      /^base_url=(.*)$/.match(@handshakeResponse)[1]
    end
    
    def adjust(uri)
      puts "adjusting station #{uri}"
      adjustUri = "http://#{self.base_url}#{self.base_path}/adjust.php?session=#{self.session}&url=#{uri}&lang=de"
      adjustUri = URI.parse(adjustUri)
      @adjustResponse = Net::HTTP.get adjustUri
    end
    
    def xspf
      xspfUri = "http://#{self.base_url}#{self.base_path}/xspf.php?sk=#{self.session}&discovery=0&desktop=1.5.1"
      xspfUri = URI.parse(xspfUri)
      xspfResponse = Net::HTTP.get xspfUri
      xspfResponse
    end
    
    def tracks
      puts "getting tracks"
      x = XSPF.new(self.xspf)
      pl = XSPF::Playlist.new(x)
      tl = XSPF::Tracklist.new(pl)
      tl.tracks
    end
    
    def download(do_loop = true)
      if @adjustResponse.nil?
        puts "please use adjust first"
      else
        while do_loop
          self.tracks.each do |track|
            begin
              outFile = "#{track.creator} - #{track.title}.mp3"
              next if File.exists?(outFile)
              puts "downloading #{outFile}"
              wget = `which wget`
              `\`which wget\` -O "#{outFile}" #{track.location}`
              tag = ID3Lib::Tag.new(outFile)
              tag.artist = track.creator
              tag.title = track.title
              unless track.album.nil?
                tag.album = track.album
              else
               tag.album = "Unknown Album"
              end
              tag.update!
              puts "finished #{outFile}"
            rescue
              puts "something went wrong!"
            end
          end
        end
      end
    end
    
  end
  
end


if ARGV.length == 3
  station = LeechFM::Station.new ARGV[0], ARGV[1]
  station.adjust ARGV[2]
  station.download
else
  puts "Usage: leechfm <username> <password> <stationuri>"
end

