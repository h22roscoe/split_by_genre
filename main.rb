require "rspotify"
require "set"
require "pp"
require "yaml/store"
require "omniauth"
require "sinatra"
require "rspotify/oauth"

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

use Rack::Session::Cookie
use OmniAuth::Builder do
  provider :spotify, ENV["SPOTIFY_CLIENT_ID"], ENV["SPOTIFY_CLIENT_SECRET"], scope: 'playlist-modify-public user-library-read user-library-modify'
end

get '/' do
  <<-HTML
  <a href='/auth/spotify'>Sign in with Spotify</a>
  HTML
end

RSpotify.authenticate(ENV["SPOTIFY_CLIENT_ID"], ENV["SPOTIFY_CLIENT_SECRET"])

me = RSpotify::User.find("h22roscoe")
get '/auth/:name/callback' do
  auth = request.env['omniauth.auth']
  me = RSpotify::User.new auth

  playlist = RSpotify::Playlist.find("h22roscoe", me.playlists.last.id)

  if not File.exists?("genres.store")
    songs = playlist.all_tracks

    store = YAML::Store.new "genres.store"
    genres_hash = {}

    songs.each do |s|
      s.artists.each do |a|
        a.genres.each do |g|
          if genres_hash.has_key?(g) then
            genres_hash[g].add(s)
          else
            genres_hash[g] = Set[s]
          end
        end if not a.genres.nil?
      end
    end

    store.transaction do
      store["genres"] = genres_hash
    end
  else
    store = YAML::Store.new "genres.store"
    store.transaction(true) do
      genres_hash = store["genres"]
    end
  end

  sorted = genres_hash.sort_by { |_k, v| v.length }.to_h
  sorted = discard_subsets(sorted)

  should_be_unioned = [
    ["rap", "hip hop", "pop rap", "southern hip hop", "brazilian hip hop", "alternative hip hop", "underground pop rap", "trap francais", "trap latino", "norwegian hip hop", "finnish hip hop", "hip pop", "underground hip hop", "west coast trap", "abstract hip hop", "underground rap", "uk hip hop", "east coast hip hop", "dirty south rap", "turntablism", "vapor trap", "grime", "electronic trap", "rap chileno"],

    ["rock", "modern rock", "indie r&b", "indietronica", "indie rock", "uk post-punk", "indie christmas", "brill building pop", "rock-and-roll", "punk", "chamber psych", "blues-rock", "madchester", "roots rock", "freak folk", "indie pop", "garage rock", "pop rock", "mellow gold", "dance-punk", "brooklyn indie", "new rave", "synthpop", "psychedelic rock", "folk rock", "classic funk rock", "alternative rock", "art rock", "classic rock", "indie folk", "chamber pop", "permanent wave", "folk-pop", "alternative dance", "neo-psychedelic", "protopunk", "swedish indie pop", "german pop", "etherpop", "kiwi rock", "jam band", "ska", "modern blues", "neo mellow", "portland indie", "indie poptimism", "swedish indie rock", "indie psych-rock", "sheffield indie", "stomp and holler", "soft rock", "glam rock", "zolo", "post-grunge", "new wave", "nu gaze", "dance rock", "dream pop", "shimmer pop", "noise pop", "australian alternative rock", "la indie", "britpop", "melancholia", "post-punk", "slow core"],

    ["pop", "dance pop", "pop christmas", "reggaeton", "r&b", "escape room", "neo soul", "electro", "trap soul", "urban contemporary", "alternative r&b", "indie psych-pop", "latin", "hip house", "deep indie r&b", "aussietronica", "canadian pop", "art pop", "metropopolis", "viral pop", "post-teen pop", "new wave pop", "australian dance", "deep pop r&b", "europop"],

    ["electronic", "electroclash", "trip hop", "edm", "tropical house", "electro", "aussietronica", "disco house", "brostep", "float house", "house", "uk garage", "ninja", "electro house", "microhouse", "downtempo", "big beat", "bass music", "nu jazz", "electronic trap", "filter house"],

    ["wonky", "future garage", "downtempo", "dubstep", "float house", "vapor twitch", "fluxwork", "indie jazz", "future funk", "lo beats"],

    ["classical", "fourth world", "compositional ambient", "ambient", "bow pop", "soundtrack"],

    ["reggae", "roots reggae", "reggae fusion", "rock steady", "a cappella", "dancehall"],

    ["world", "rai", "afropop", "afrobeat", "world christmas", "afrobeats", "latin jazz", "flamenco", "electro swing", "surf music"],

    ["disco", "quiet storm", "jazz funk", "funk"],

    ["folk", "folk christmas", "folk rock", "indie folk", "folk-pop", "freak folk", "singer-songwriter", "contemporary country", "traditional country"],

    ["k-pop", "korean pop"],

    ["soul", "soul christmas", "doo-wop", "traditional soul", "soul jazz", "memphis soul", "motown", "soul blues", "chicago soul", "soul flow", "christmas"],

    ["jazz", "soul jazz", "electric blues", "contemporary jazz", "cabaret", "jazz blues", "bossa nova", "adult standards", "quiet storm", "vocal jazz", "jazz christmas"]
  ]

  sorted = union_sets(should_be_unioned, sorted)
  sorted = discard_subsets(sorted)

  sorted.each do |k, v|
    playlist = me.create_playlist! k
    copy = v.to_a.sort_by { |t| t.artists.first.name }
    while copy.size > 0
      playlist.add_tracks!(copy.slice!(0, 100))
    end

    print "Created ", playlist.name
  end

  <<-HTML
  <h1>done</h1>
  HTML
end

def union_sets(to_be_ud, sets)
  hash = sets
  to_be_removed = []
  to_be_ud.each do |gs|
    hash[gs[0]] = gs.map { |g| sets[g] }.reduce(Set[], :|)
    to_be_removed += gs[1 .. -1]
  end

  hash.delete_if { |k, v| to_be_removed.member?(k) }
end

def discard_subsets(hash_of_sets)
  new_round = hash_of_sets
  this_round = {}
  last_round = {}

  until new_round == last_round do
    this_round = {}
    last_round = new_round
    new_round.each do |k, v|
      found_sub = false
      new_round.each do |k2, v2|
        if v < v2
          found_sub = true
        end
      end

      this_round[k] = v unless found_sub
    end

    new_round = this_round
  end

  new_round
end
