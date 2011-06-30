# Copyright (c) 2011 ActiveState Software Inc.
# See the file LICENSE.txt for licensing information.

class HarvesterController < ApplicationController
  
  Candidates =  [["Barack<br>Obama",  "3366CC"],
       ["Michele<br>Bachmann", "DC3912"],
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
       ]
  @@url_base = 'http://search.twitter.com/search.json'
  def hello
    render :text => "hello"
  end
  
  def initApp
    Candidate.delete(:all)
    if Meta.count == 0
      Meta.create(:processTime => (Time.now - 6.hours).utc)
      self.reload(false)
      self.stopWords(false)
    end
    render :text => Meta.find(:first).processTime.utc
  end
  
  def reload(doRender=true)
    Candidates.each do |line, color|
      fname, lname = line.split("<br>")
      Candidate.create({:firstName => fname, :lastName => lname, :color => color})
    end
    if doRender
      render :text => Candidate.count
    end
  end
  
  def stopWords(doRender=true)
    File.open(File.expand_path("../stopWords.txt", __FILE__), "r") do |fd|
      fd.readlines.map{|s|s.chomp}.each { |wd| StopWord.create(:word => wd) }
    end
    if doRender
      render :text => StopWord.count
    end
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
    render :text => (Meta.find(:first).processTime - 1.hour).to_i 
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
  
    
    @@hashtagSplitter = /(?:\A|\W)#([\-\_\w]+)/
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
        $stderr.puts "************** In getRawTweets"
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
          rawCreationTime_a = Date::parse(rawCreationTime).to_time.utc.to_a
        else
          rawCreationTime_a = ParseDate::parsedate(rawCreationTime)
        end
        parsedTime = Time.gm(*rawCreationTime_a)
      rescue
        msg = "Error parsing date: #{$!}, rawCreationTime:#{rawCreationTime}"
        @log.debug(msg)
        return {:status => 1, :reject => msg}
      end
      $stderr.puts("parsedTime:#{parsedTime}, lastStopTime:#{lastStopTime}, test:#{parsedTime < lastStopTime}")
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
      currentTweet = Tweet.find_by_tweetId(tweetId)
      if currentTweet
        if verbose==VERBOSE_MAX
          @log.debug("Already saw tweet #{tweetId}")
        end
        return {:status => 1, :reject => "DUPLICATE_TWEET"}
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
          return {:status => 1, :reject => "CANT_CREATE_TWITTER_USER", :details => $!.to_s}
        end
      end
      text = params[:text]
      if verbose==VERBOSE_MAX
          @log.debug("Save tweet: text:%s(%d),user:%s, id:%s" % 
                [text, text.size, twitterUser, tweetId])
      end
      tweet = findMainTextPart(text, parsedTime)
      if tweet
        # See if the tweet references more than one candidate.
        if candidate.tweets.find_by_text(text)
          @log.debug("Already saw tweet <#{text}> for this candidate")
        else
          candidate.tweets << tweet
        end
        return {:status => 1, :reject => "COPIED_TWEET"}
      end
      begin
        tweet = Tweet.new({:text=>text,
                            :publishedAt=>parsedTime,
                            :twitter_user_id => twitterUser.id,
                            :tweetId=>tweetId})
      rescue
        msg = $!.to_s
        if msg != "Validation failed: Text has already been taken"
          @log.error("Can't save a tweet (text:%s(%d)): %s" % [text, text.size, msg])
        end
        return {:status => 1, :reject => "COPIED_TWEET", :details => $!.to_s}
      end
      begin
        twitterUser.tweets << tweet
      rescue
        @log.error("Can't associate tweet %s with user %s: %s" %
                   [ tweet.text, twitterUser.userName, $!])
        return {:status => 1, :reject => "CANT_ASSOCIATE_TWITTER_USER", :details => $!.to_s}
      end
      begin
        candidate.tweets << tweet
      rescue
        @log.error("Can't do candidate.tweets << tweet: #{$!}")
        return {:status => 1, :reject => "CANT_MAKE_CANDIDATE_TWEETS_ENTRY", :details => $!.to_s}
      end
      begin
        text.scan(@@hashtagSplitter) do | hword |
          hword.each do |hw|
            hashtag = Hashtag.find_by_hashtag(hw)
            if hashtag.nil?
              hashtag = Hashtag.new(:hashtag => hw)
              begin
                hashtag.save!
              rescue
                @log.error("Can't do hashtag.save!tweet: #{$!}")
                return {:status => 1, :reject => "CANT_SAVE_HASHTAG", :details => $!.to_s}
              end
            end
            begin
              tweet.hashtags << hashtag
              tweet.save!
            rescue
              @log.error("Can't do tweet.hashtags << hashtag: #{$!}")
              return {:status => 1, :reject => "CANT_SAVE_HASHTAG_WITH_TWEET", :details => $!.to_s}
            end
          end # end inner each
        end # end text.scan
      rescue
        @log.error("Can't assoc tweets and hashtags: #{$!}")
      end
      return {:status => 0}
    end
  
    def findMainTextPart(text, publishedTime)
      # Allow a dup every four hours
      fourHoursAgo = publishedTime - 4.hours
      tweet = Tweet.find(:first, :conditions => ["text = ? and publishedAt >= ?", text, fourHoursAgo], :order => "publishedAt DESC" )
      return tweet if tweet
      linkFreeText = text.gsub('%', '\\%').
                          gsub('_', '\\_').
                          gsub(/\bhttp:\/\/[\S+]/, "%")
      return nil if linkFreeText == text
      tweet = Tweet.find(:first,
                          :conditions => ["text like ? and publishedAt >= ?",
                                          linkFreeText, fourHoursAgo],
                          :order => "publishedAt DESC"
                         )
      return tweet
    end
  end # class
  
end
