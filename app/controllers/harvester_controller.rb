class HarvesterController < ApplicationController
  
  Candidates =  [["Barack<br>Obama",  "3366CC"],
       ["Michele<br>Bachmann", "DC3912"], # give up on"F02288"]
       ["Herman<br>Cain", "FF9900"],
       ["Newt<br>Gingrich", "109618"],
       ["Jon<br>Huntsman", "990099"],
       ["Gary<br>Johnson", "0099C6"],
       ["Sarah<br>Palin", "FF2288"],
       ["Ron<br>Paul", "66AA00"],
       ["Tim<br>Pawlenty", "B82E2E"],
       ["Mitt<br>Romney", "316395"],
       ["Rick<br>Santorum", "775500"],
       ["Rick<br>Perry", "22AA99"],
       ["Chris<br>Christie", "FFEE11"],
       ["Paul<br>Ryan", "CCFF33"],
       ]

  @@url_base = 'http://search.twitter.com/search.json'
  def hello
    render :text => "hello"
  end
  
  def setTrackTime(doRender=true)
    trackTimeRecord = Meta.find(:first)
    if trackTimeRecord.nil?
      raise("run gatherTweets init first")
    end
    trackTimeRecord.processTime = Time.now.utc
    trackTimeRecord.save!
    if doRender
      render :text => trackTimeRecord.processTime
    end
  end
  
  def setTrackTimeYesterday(doRender=true)
    trackTimeRecord = Meta.find(:first)
    if trackTimeRecord.nil?
      raise("run gatherTweets init first")
    end
    trackTimeRecord.processTime = (Time.now - 1.day).utc
    trackTimeRecord.save!
    if doRender
      render :text => trackTimeRecord.processTime
    end
  end
  
  def updateLastStopTime
    #if !request.post?
    #  render :text => { :status => 1, :details => "Not a post request"}.to_json
    #end
    trackTimeRecord = Meta.find(:first)
    trackTimeRecord.processTime = Time.now.utc
    trackTimeRecord.save!
    render :text => { :status => 0 }.to_json
  end
  
  def updateTweet
    #if !request.post?
    #  render :text => { :status => 1, :details => "Not a post request"}.to_json
    #end
    render :text => TweetLoader.new().updateTweet(params).to_json
  end
  
    
  def getenv
    keys = request.env.keys
    s = []
    request.env.each do |key, value|
      s << "#{key}:#{value}"
    end
    s1 = s.join("\n")
    $stderr.puts("testPost: addr: #{s1}///")
    render :text => s1
  end
    
  def getTweets
    verbose = params[:verbose]
    candidateID = params[:candidateID]
    lastStopTime = Time.at(params[:lastStopTime].to_i)
    nextPageURL = params[:nextPageURL]
    render :text => TweetLoader.new().getRawTweets(candidateID, lastStopTime, verbose, nextPageURL)
  end
  
  def getLastStopTime
    # Allow for some leeway -- it takes about an hour to run through all the tweets, so we
    # need to look further back.
    begin
      render :text => (Meta.find(:first).processTime - 1.hour).to_i
    rescue
      render :text => ""
    end
  end
  
  def getNumberOfCandidates
    render :text => Candidate.count
  end
  
  def getFirstCandidateID
    render :text => Candidate.find(:first).id
  end
  
  def getNextCandidateID
    candidateID = params[:candidateID].to_i
    maxID = Candidate.maximum(:id)
    while true
      begin
        candidateID += 1
        Candidate.find(candidateID)
        break
      rescue ActiveRecord::RecordNotFound
        if candidateID > maxID
          candidateID = -1
          break
        end
      end
    end
    render :text => candidateID
  end
  
  private
  
  class MyLogger
    attr_accessor :level
    @fd = STDERR
    DEBUG = 1
    ERROR = 3
    def initialize(fd)
      @fd = fd
      @fd.sync = true
      @fd.puts
    end
    def debug(msg)
      @fd.puts(msg) if @level >= DEBUG
    end
    def error(msg)
      @fd.puts(msg) if @level >= DEBUG
    end
    def puts(msg)
      @fd.puts(msg)
    end
  end
  $is_19 = (RUBY_VERSION.split(/\./).map{|a|a.to_i} <=> [1,9,0]) >= 0
  if $is_19
    require 'date'
  else
    require 'parsedate'
  end
  
  $stderr.sync = true
  
  require "open-uri"
  require 'logger'
  
  VERBOSE_MAX = 2
  VERBOSE_MIN = 1
  VERBOSE_OFF = 0

  class TweetLoader
  
    
    @@url_base = 'http://search.twitter.com/search.json'
    def initialize
      @@_spammers = {
        
      }
      #@log = MyLogger.new(STDERR)   # File.open("../logs/gatherTweets.log", "w"))
      @log = MyLogger.new(File.open("/tmp/gatherTweets.log", "w"))
      @log.level = MyLogger::DEBUG
    end
    
    def getRawTweets(candidateID, lastStopTime, verbose, nextPageURL)
      #fdx = File.open("/tmp/gatherTweets2.log", "w")
      #fdx.sync = true
      if nextPageURL.nil?
        candidate = Candidate.find(candidateID)
        #$stderr.puts "************** In getRawTweets"
        #fdx.puts "************** In getRawTweets"
        firstName = candidate.firstName
        lastName = candidate.lastName
        search_part = "?q=%s+%s" % [URI.escape(firstName), URI.escape(lastName)]
      else
        search_part = nextPageURL
      end
      searchURL = @@url_base + search_part
    
      @log.puts("About to get #{searchURL}")
      begin
        return open(searchURL) {|fd| fd.read  }
      rescue
        $stderr.puts("Error searching tweets: searchURL:#{searchURL}, $!:#{$!}")
        return $!.to_s
      end
    end
    
    def updateTweet(params)
      verbose = params[:verbose]
      candidateID = params[:candidateID]
      lastStopTime = Time.at(params[:lastStopTime].to_i).utc
      nextPageURL = params[:nextPageURL]
      # %W/created_at from_user_id_str from_user profile_image_url text id/.each do |s|
      rawCreationTime=params['created_at']
      begin
        if $is_19
          rawCreationTime_a = DateTime::parse(rawCreationTime).to_time.utc.to_a
        else
          rawCreationTime_a = ParseDate::parsedate(rawCreationTime)
        end
        parsedTime = Time.gm(*rawCreationTime_a)
      rescue
        msg = "Error parsing date: #{$!}, rawCreationTime:#{rawCreationTime}"
        @log.debug(msg)
        return {:status => 1, :reject => msg}
      end
      #$stderr.puts("parsedTime:#{parsedTime}, lastStopTime:#{lastStopTime}, test:#{parsedTime < lastStopTime}")
      if parsedTime < lastStopTime
        # The driver should do this, not the server
        @log.debug("We hit older tweets: #{params[:text]}, #{rawCreationTime}")
        return {:status => 1, :reject => "TOO_OLD"}
      end
      userName=params['from_user']
      if @@_spammers[userName]
        if verbose==VERBOSE_MAX
            @log.debug("Skip spammer #{userName}")
        end
        # Skip the tweet
        return {:status => 1, :reject => "SPAMMER"}
      end
      userId = params['from_user_id_str']
      tweetId = params['id']
      candidate = Candidate.find(candidateID)
      # Did we already process this tweet?
      currentTweet = Tweet.find_by_tweetId(tweetId) || DuplicateTweet.find_by_tweetId(tweetId)
      if currentTweet
        if verbose==VERBOSE_MAX
          @log.debug("Already saw tweet #{tweetId}")
        end
        return {:status => 1, :reject => "DUPLICATE_TWEET"}
      end
      text = params[:text]
      tweetData = parseTweet(text)
      #$stderr.puts("stderr: rawText: #{tweetData[:textKernel]}")
      @log.puts("@log: rawText: #{tweetData[:textKernel]}")
      #a = {
      #  :retweet => m[1],
      #  :textKernel => m[2],
      #  :trailingTagsAndLinks => m[3]
      #}
      
      fourHoursAgo = parsedTime - 4.hours
      olderTweet = Tweet.find(:first, :conditions => ["textKernel = ? and publishedAt >= ?",
                                                      tweetData[:textKernel], fourHoursAgo],
                              :order => "publishedAt DESC" )
      if olderTweet
        #XXXX todo: if we now have the actual underlying tweet, use that instead of the retweet
        DuplicateTweet.create(:tweetId => tweetId, :orig_tweet_id => olderTweet.id)
        return {:status => 1, :reject => "COPIED_TWEET"}
      else
        olderTweet = Tweet.find_by_textKernel(tweetData[:textKernel])
        if olderTweet
          #$stderr.puts("Found an older tweet: parsedTime:#{parsedTime}, 4hrs ago:#{fourHoursAgo}, oldTweetTime:#{olderTweet.publishedAt}")
          DuplicateTweet.create(:tweetId => tweetId, :orig_tweet_id => olderTweet.id)
          return {:status => 1, :reject => "COPIED_TWEET"}
        end
        
      end
      twitterUser = TwitterUser.find_by_userId(userId)
      if ! twitterUser
        begin
          twitterUser = TwitterUser.new({:userId=>userId,
                                         :userName=>userName,
                                         :profileImageUrl => params['profile_image_url']})
          twitterUser.save!
        rescue
          @log.error("** prob creating twitter user #{params['from_user']}: #{$!}")
          if $!.to_s =~ /^Mysql2::Error: INSERT command denied/
            return {:status => 1, :reject => "MYSQL_PERMISSIONS_ERROR", :details => $!.to_s}
          end
          return {:status => 1, :reject => "CANT_CREATE_TWITTER_USER", :details => $!.to_s}
        end
      end
      if verbose==VERBOSE_MAX
          @log.debug("Save tweet: text:%s(%d),user:%s, id:%s" % 
                [text, text.size, twitterUser, tweetId])
      end
      tweetScores = parseTweetScores(tweetData[:textKernel])
      begin
        tweet = Tweet.new({:text=>makeSafeViewableHTML(text),
                           :textKernel => tweetData[:textKernel],
                           :publishedAt=>parsedTime,
                           :twitter_user_id => twitterUser.id,
                           :sentimentScore => tweetScores[:sentimentScore],
                           :positiveWordCount => tweetScores[:positiveWordCount],
                           :negativeWordCount => tweetScores[:negativeWordCount],
                           :tweetId=>tweetId})
      rescue
        msg = $!.to_s
        if msg != "Validation failed: Text has already been taken"
          @log.error("Can't save a tweet (text:%s(%d)): %s" % [text, text.size, msg])
        end
        return {:status => 1, :reject => "TWEET_CREATION_FAILURE", :details => $!.to_s}
      end
      begin
        twitterUser.tweets << tweet
      rescue
        @log.error("Can't associate tweet %s with user %s: %s" %
                   [ tweet.text, twitterUser.userName, $!])
        if $!.to_s =~ /^Mysql2::Error: INSERT command denied/
          return {:status => 1, :reject => "MYSQL_PERMISSIONS_ERROR", :details => $!.to_s}
        end
        return {:status => 1, :reject => "CANT_ASSOCIATE_TWITTER_USER", :details => $!.to_s}
      end
      begin
        candidate.tweets << tweet
      rescue
        @log.error("Can't do candidate.tweets << tweet: #{$!}")
        return {:status => 1, :reject => "CANT_MAKE_CANDIDATE_TWEETS_ENTRY", :details => $!.to_s}
      end
      return {:status => 0}
    end
  
    @@linkStart_re = /\A<[^>]*?href=["']\Z/
    @@splitter = /(<[^>]*?href=["']|http:\/\/[^"' \t]+)/
    def makeSafeViewableHTML(text)
      revEnts = [
          ['&lt;', '<'],
          ['&gt;', '>'],
          ['&quot;', '"'],
          ['&apos;', '\''],
          ['&amp;', '&'],
      ]
      revEnts.each { |src, dest| text.gsub(src, dest) }
      pieces = text.split(@@splitter).grep(/./)
      lim = pieces.size
      piece = pieces[0]
      madeChange = false
      (1 .. lim - 1).each do |i|
        prevPiece = piece
        piece = pieces[i]
        if piece.index('http://') == 0 && @@linkStart_re !~ prevPiece
          pieces[i] = '<a href="%s" target="_blank">%s</a>' % [piece, piece]
          madeChange = true
        end
      end
      #TODO: Watch out for on* attributes and script & style tags
      return madeChange ? pieces.join("") : text
    end
    
    # Note on this regex: match a single '\s' before \Z in that last ((?:...|\s)*)
    # piece, not \s+. With the \s+,
    # Ruby and Python take a long time to match a pattern like this,
    # Perl and PHP find it instantly, and JS complains that the regex
    # is too complex.
    @@tweetParser = /\A(\s*(?:(?:RT\b[\s:]*)?(?:@[a-zA-Z][\w\-.]*[,:\s]*))*)
                     (.*?)
                     ((?:http:\/\/.*?\/\S+|[\#\@][a-zA-Z][\w\-.]*|\s)*)\Z/mx
    def parseTweet(text)
      m = @@tweetParser.match(text)
      if m.nil?
        $stderr.puts("parseTweet: Failed to match ")
      end
      return {
        :retweet => m[1],
        :textKernel => m[2],
        :trailingTagsAndLinks => m[3]
      }
    end
    def parseTweetScores(text)
      return {:positiveWordCount => 0,
                     :negativeWordCount => 0,
                     :sentimentScore => 0
      }
    end
    def parseTweetScoresWhenNeeded(text)
      text.gsub!(/\bhttp:\/\/.*?\/\S+/, "")
      text.gsub!(/\&\w+;/, "")
      text.gsub!(/[\#\@][a-zA-Z]\w*/, "")
      text.gsub!(/(?:\A|\s)'(\w.*?\w)'/, '\1')
      posCount = 0
      negCount = 0
      
      words = text.split(/[^\w']+/)
      if words.size == 0
        return 0
      end
      conn = PositiveWord.connection
      qpart = words.map{|wd| "word = #{conn.quote(wd.downcase)}" }.join(" OR ")
      #$stderr.puts "separate words: <<#{qpart}>>"
      
      posCount = negCount = 0
      query = "select count(*) from positive_words where " + qpart
      posCount = conn.select_rows(query)[0][0]
      
      conn = NegativeWord.connection
      query = "select count(*) from negative_words where " + qpart
      negCount = conn.select_rows(query)[0][0]
      
      tweetScores = {:positiveWordCount => posCount,
                     :negativeWordCount => negCount,
                     :sentimentScore => posCount - negCount
      }
    end
  end # class
  
end
