module CI
  class Recording < Asset
    api_attr_reader   :tracks, :files, :ISRC, :Duration
    api_attr_reader   :LabelName, :Producers, :Mixers
    api_attr_reader   :Composers, :Lyricists
    api_attr_reader   :MainArtist, :FeaturedArtists, :Artists
  end
end



class CI::Recording < CI
  ci_properties :tracks, :LabelName, :files, :Composers, :Lyricists, :Producers, :MainArtist, :Artists, :Mixers, :Publishers, :ISRC, :FeaturedArtists, :Duration
  self.uri_path = "/recording/isrc"
  
  alias_method :id, :isrc
  
  def tracks
    @params['tracks'] || []
  end
  
  def tracks=(tracks)
    @params['tracks'] = tracks.map do |track|
      klass = track['__class__'].sub('API', 'CI').constantize
      klass.new(track)
    end
  end
  
  def files
    @params['files'] || []
  end
  
  def files=(files)
    @params['files'] = files.map do |file|
      klass = file['__class__'].sub('API', 'CI').constantize
      klass.new(file)
    end
  end
  
  def newest_track
    CI::Track.do_request(:get, "#{id}/newest")
  end
  
  #TODO add methods to get encodings etc.
  
  #TODO these should go in CI.rb, once Eleanor's commited her changes. they're all class methods.
  #Also, get rid of exceptional mappings gubbins and capitalize bit from ci_properties, and make method definitions conditional on them not being defined already.
  
  
end