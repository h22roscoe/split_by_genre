require "rspotify"

class RSpotify::Playlist
  def all_tracks(market: nil)
    all = []
    offset = 0
    new_added = []
    begin
      new_added = self.tracks(limit: 100, offset: offset, market: market)
      all += new_added
      offset += 100
    end while new_added.size == 100

    return all
  end
end

RSpotify.authenticate(ENV["SPOTIFY_CLIENT_ID"], ENV["SPOTIFY_CLIENT_SECRET"])

me = RSpotify::User.find('h22roscoe')
playlist = RSpotify::Playlist.find('h22roscoe', me.playlists.last.id)

songs = playlist.all_tracks

songs.first(50).each do |song|
  p song.artists.flatten.map { |artist| artist.genres }
end
