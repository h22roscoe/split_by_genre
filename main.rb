require "rspotify"
require "set"
require "pp"
require "yaml/store"
require "omniauth"
require "sinatra"
require "rspotify/oauth"
require "progress_bar"

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

class RSpotify::User
  def all_tracks()
    all = []
    offset = 0
    new_added = []
    begin
      new_added = self.saved_tracks(limit: 50, offset: offset)
      all += new_added
      offset += 50
    end while new_added.size == 50
    return all
  end
end

class RSpotify::Base
  def ==(other)
    if other.kind_of? RSpotify::Base then
      self.id == other.id
    else
      false
    end
  end
end

use Rack::Session::Cookie
use OmniAuth::Builder do
  provider :spotify, ENV["SPOTIFY_CLIENT_ID"], ENV["SPOTIFY_CLIENT_SECRET"], scope: "playlist-modify-public user-library-read user-library-modify"
end

RSpotify.authenticate(ENV["SPOTIFY_CLIENT_ID"], ENV["SPOTIFY_CLIENT_SECRET"])

get "/" do
  <<-HTML
  <a href='/auth/spotify'>Sign in with Spotify</a>
  HTML
end

get "/auth/:name/callback" do
  auth = request.env["omniauth.auth"]
  me = RSpotify::User.new auth
  # split_up_songs(me)
  artists_hash = favourite_artists(me)

  artists_hash.each do |a, songs|
    puts RSpotify::Artist.find(a).name, songs.length
  end

  <<-HTML
  <h1>Done</h1>
  HTML
end

def favourite_artists(me)
  songs = me.all_tracks.uniq
  artists_hash = {}
  songs.each do |s|
    s.artists.each do |a|
      if artists_hash.has_key?(a.id) then
        artists_hash[a.id].add(s)
      else
        artists_hash[a.id] = Set[s]
      end
    end
  end

  artists_hash.sort_by { |_k, v| -v.length }[0...20].to_h
end

def split_up_songs(me, create=false)
  if not File.exists?("genres.store")
    songs = me.all_tracks.uniq

    store = YAML::Store.new "genres.store"
    genres_hash = {}

    bar = ProgressBar.new(songs.size)
    songs.each do |s|
      s.artists.first.genres.each do |g|
        if genres_hash.has_key?(g) then
          genres_hash[g].add(s)
        else
          genres_hash[g] = Set[s]
        end
      end unless s.artists.first.genres.nil?
      bar.increment!
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

  should_be_unioned = [
    ["rap", "hip hop", "pop rap", "southern hip hop", "brazilian hip hop", "alternative hip hop", "underground pop rap", "trap francais",
     "trap latino", "norwegian hip hop", "finnish hip hop", "hip pop", "underground hip hop", "west coast trap", "abstract hip hop", "bassline", "gangster rap",
     "underground rap", "uk hip hop", "east coast hip hop", "dirty south rap", "turntablism", "vapor trap", "grime", "electronic trap", "rap chileno",
     "hardcore hip hop", "west coast rap", "detroit hip hop", "g funk", "crunk", "hyphy", "old school hip hop"],

    ["trap music", "trap francais", "dwn trap", "electronic trap", "trap latino", "west coast trap", "vapor trap", "drill", "deep trap",
     "bass trap", "west coast trap", "electronic trap"],

    ["rock", "modern rock", "indietronica", "indie rock", "uk post-punk", "indie christmas", "rock-and-roll", "punk", "symphonic rock",
     "chamber psych", "blues-rock", "madchester", "roots rock", "freak folk", "indie pop", "garage rock", "new weird america", "canadian indie",
     "pop rock", "mellow gold", "dance-punk", "brooklyn indie", "new rave", "synthpop", "psychedelic rock", "folk rock", "classic funk rock",
     "alternative rock", "art rock", "classic rock", "chamber pop", "permanent wave", "folk-pop", "alternative dance", "neo-psychedelic",
     "protopunk", "swedish indie pop", "german pop", "etherpop", "kiwi rock", "jam band", "ska", "modern blues", "portland indie", "shoegaze",
     "indie poptimism", "swedish indie rock", "indie psych-rock", "sheffield indie", "stomp and holler", "soft rock", "glam rock", "zolo", "post-grunge",
     "new wave", "nu gaze", "dance rock", "dream pop", "shimmer pop", "noise pop", "australian alternative rock", "la indie", "britpop", "pub rock",
     "melancholia", "post-punk", "slow core", "mashup", "album rock", "lo-fi", "chillwave", "punk blues", "british invasion", "new romantic",
     "british blues", "hard rock", "piano rock", "merseybeat", "experimental rock", "alt-indie rock", "noise rock", "austindie", "heavy christmas",
     "preverb", "indie garage rock", "progressive rock", "power pop", "post rock", "punk christmas", "pop punk", "garage psych", "no wave",
     "alternative metal", "post-hardcore", "experimental", "mod revival", "indie punk", "albuquerque indie"],

    ["pop", "dance pop", "pop christmas", "reggaeton", "r&b", "escape room", "neo soul", "electro", "trap soul", "urban contemporary", "alternative r&b",
     "indie psych-pop", "latin", "hip house", "deep indie r&b", "aussietronica", "canadian pop", "art pop", "metropopolis", "viral pop", "post-teen pop",
     "new wave pop", "australian dance", "deep pop r&b", "europop", "neo mellow", "indie r&b", "uk garage", "british invasion", "grave wave",
     "new jack swing", "power pop", "moombahton", "candy pop", "liquid funk", "big room"],

    ["electronic", "electroclash", "trip hop", "edm", "tropical house", "electro", "aussietronica", "disco house", "brostep",
      "float house", "nu disco", "house", "ninja", "electro house", "microhouse", "downtempo", "big beat", "bass music", "big room",
      "nu jazz", "electronic trap", "filter house", "deep house", "minimal techno", "acid house", "progressive house",
      "vocal house", "drum and bass"],

    ["wonky", "future garage", "dubstep", "float house", "vapor twitch", "fluxwork", "indie jazz", "future funk", "lo beats",
     "intelligent dance music", "glitch hop", "acid techno", "glitch", "minimal techno", "hauntology"],

    ["classical", "fourth world", "compositional ambient", "ambient", "bow pop", "soundtrack", "classical christmas", "post rock", "focus", "romantic era"],

    ["reggae", "roots reggae", "reggae fusion", "rock steady", "a cappella", "dancehall", "dub"],

    ["world", "rai", "afropop", "afrobeat", "world christmas", "afrobeats", "latin jazz", "flamenco", "electro swing", "surf music", "mexican rock-and-roll"],

    ["disco", "quiet storm", "jazz funk", "funk", "deep funk"],

    ["folk", "folk christmas", "folk rock", "indie folk", "folk-pop", "freak folk", "singer-songwriter", "contemporary country", "traditional country", "anti-folk", "lilith"],

    ["k-pop", "korean pop", "k-hop"],

    ["soul", "southern soul", "soul christmas", "doo-wop", "traditional soul", "soul jazz", "memphis soul", "motown", "soul blues", "blues",
     "chicago soul", "soul flow", "christmas", "brill building pop", "northern soul", "rockabilly", "bubblegum pop", "lounge",
     "memphis blues", "traditional blues", "texas blues", "piedmont blues", "louisiana blues", "delta blues", "chicago blues"],

    ["jazz", "soul jazz", "electric blues", "contemporary jazz", "cabaret", "jazz blues", "bossa nova", "adult standards",
     "quiet storm", "vocal jazz", "jazz christmas", "bebop", "cool jazz", "hard bop", "contemporary post-bop", "swing"]
  ]

  sorted = union_sets(should_be_unioned, sorted)

  if create then
    create_playlists(me, sorted)
  else
    sorted.each do |genre, ss|
      puts
      puts genre
      ss.each { |s| print s.name, " " }
    end
  end
end

def create_playlists(me, sorted)
  sorted.each do |k, v|
    playlist = me.create_playlist! k
    copy = v.to_a.sort_by { |t| t.artists.first.name }
    while copy.size > 0
      playlist.add_tracks!(copy.slice!(0, 100))
    end

    puts "Created ", playlist.name
  end
end

def union_sets(to_be_ud, sets)
  hash = sets
  to_be_kept = []
  to_be_ud.each do |gs|
    hash[gs[0]] = gs.map { |g| if sets[g].nil? then Set[] else sets[g] end }.reduce(Set[], :|)
    to_be_kept << gs[0]
  end

  hash.select { |k, v| to_be_kept.member?(k) }
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
