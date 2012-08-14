class BatchHarvester
  
  @@url_base = 'http://search.twitter.com/search.json'

  def initialize(verbose=false)
    @tweetLoader = TweetLoader.new
    @verbose = verbose
  end

  def updateLastStopTime
    trackTimeRecord = Meta.find(:first)
    trackTimeRecord.processTime = Time.now.utc
    trackTimeRecord.save!
  end

  def updateTweets
    numCandidates = Candidate.count
    candidateID = Candidate.minimum(:id)
    @lastStopTime = begin (Meta.find(:first).processTime - 1.hour).to_i rescue 0 end
    100000.times do # Unreasonable sentinel value
      $stderr.puts("**************** getTweetsForCandidate(candidateID:#{candidateID} ****************\n\n\n") if @verbose
      getTweetsForCandidate(candidateID)
      nextCandidateID = getNextCandidateID(candidateID)
      if nextCandidateID.nil?
        $stderr.puts("getNextCandidateID(#{candidateID}) => null")
        break
      end
      candidateID = nextCandidateID
    end
    updateLastStopTime
  end

  private

  def getTweetsForCandidate(candidateID)
    nextPageURL = nil
    lim = 30 # worst-case sentinel
    lim.times do
      searchResult = @tweetLoader.getRawTweets(candidateID, @lastStopTime, @verbose, nextPageURL)
      next if searchResult.size == 0
      #$stderr.puts("**************** getTweetsForCandidate: searchResult:#{searchResult}") if @verbose
      nextPageURL = searchResult['next_page']
      tweets = searchResult['results']
      $stderr.puts("**************** getTweetsForCandidate: got #{tweets.size} tweets ****************\n") if @verbose
      if not updateCurrentTweets(candidateID, tweets)
        $stderr.puts("<<<<<<<<<<<<<<<< done with candidateID:#{candidateID}") if @verbose
        return
      end
      if nextPageURL.nil? || nextPageURL.index("page=20")
        $stderr.puts("**************** getTweetsForCandidate: break: nextPageURL:#{nextPageURL} ****************\n\n\n") if @verbose
        break
      end
      # Don't throttle the twitter api
      $stderr.puts("**************** -sleep 5") if @verbose
      sleep 5
      $stderr.puts("**************** +sleep 5") if @verbose
    end
  end

  def updateCurrentTweets(candidateID, tweets)
    num_successes = 0
    tweets.each do |tweet|
      $stderr.puts("-updateTweet(tweet:#{tweet})") if @verbose
      resp = @tweetLoader.updateTweet(tweet, candidateID, @lastStopTime, @verbose)
      $stderr.puts("+updateTweet") if @verbose
      if resp[:status] == 0 || resp[:reject] == "COPIED_TWEET"
        num_successes += 1
      else
	if @verbose
	    $stderr.puts("problem updating tweet #{tweet['text']}: #{resp[:reject]}")
	end
	if resp[:reject] == "MYSQL_PERMISSIONS_ERROR"
	  return false
	end
      end
    end
    $stderr.puts("updateCurrentTweets(candidateID:#{candidateID}): num_successes:#{num_successes}") if @verbose
    return num_successes > 0
  end
  
  def getNextCandidateID(candidateID)
    maxID = Candidate.maximum(:id)
    100000.times do # Unreasonable sentinel value
      begin
        candidateID += 1
        Candidate.find(candidateID)
        return candidateID
      rescue ActiveRecord::RecordNotFound
        if candidateID > maxID
          return nil
        end
      end
    end
    $stderr.puts("getNextCandidateID hit a ridic point")
  end
  
  private
  $is_19 = (RUBY_VERSION.split(/\./).map{|a|a.to_i} <=> [1,9,0]) >= 0
  if $is_19
    require 'date'
  else
    require 'parsedate'
  end
  
  $stderr.sync = true
  
  # require "open-uri"
  require 'logger'
  
  VERBOSE_MAX = 2
  VERBOSE_MIN = 1
  VERBOSE_OFF = 0

  class TweetLoader
  
    
    @@url_base = 'http://search.twitter.com/search.json'
    def initialize
      @@_spammers = {
      }
    end
    
    def getRawTweets(candidateID, lastStopTime, verbose, nextPageURL)
      if nextPageURL.nil?
        candidate = Candidate.find(candidateID)
        #$stderr.puts "************** In getRawTweets"
        firstName = candidate.firstName
        lastName = candidate.lastName
        search_part = "?q=%s+%s" % [URI.escape(firstName), URI.escape(lastName)]
      else
        search_part = nextPageURL
      end
      searchURL = @@url_base + search_part
    
      begin
        # return open(searchURL) {|fd| JSON.load(fd)  }
	return JSON.parse(`curl '#{searchURL}'`)
        #return open(searchURL) {|fd| JSON.load(fd)  }
      rescue
        $stderr.puts("Error searching tweets: searchURL:#{searchURL}, $!:#{$!}")
        raise
      end
    end
    
    def updateTweet(tweet, candidateID, lastStopTime, verbose)
      lastStopTime = Time.at(lastStopTime.to_i).utc
      rawCreationTime = tweet['created_at']
      begin
        if $is_19
          rawCreationTime_a = DateTime::parse(rawCreationTime).to_time.utc.to_a
        else
          rawCreationTime_a = ParseDate::parsedate(rawCreationTime)
        end
        parsedTime = Time.gm(*rawCreationTime_a)
      rescue
        msg = "Error parsing date: #{$!}, rawCreationTime:#{rawCreationTime}"
        $stderr.puts(msg) if @verbose
        return {:status => 1, :reject => msg}
      end
      #$stderr.puts("parsedTime:#{parsedTime}, lastStopTime:#{lastStopTime}, test:#{parsedTime < lastStopTime}")
      if parsedTime < lastStopTime
        # The driver should do this, not the server
        $stderr.puts("We hit older tweets: #{tweet['text']}, #{rawCreationTime}") if @verbose
        return {:status => 1, :reject => "TOO_OLD"}
      end
      userName=tweet['from_user']
      if @@_spammers[userName]
        if verbose==VERBOSE_MAX
            $stderr.puts("Skip spammer #{userName}") if verbose
        end
        # Skip the tweet
        return {:status => 1, :reject => "SPAMMER"}
      end
      userId = tweet['from_user_id_str']
      tweetId = tweet['id']
      candidate = Candidate.find(candidateID)
      # Did we already process this tweet?
      currentTweet = Tweet.find_by_tweetId(tweetId) || DuplicateTweet.find_by_tweetId(tweetId)
      if currentTweet
        if verbose==VERBOSE_MAX
          $stderr.puts("Already saw tweet #{tweetId}") if verbose
        end
        return {:status => 1, :reject => "DUPLICATE_TWEET"}
      end
      text = tweet['text']
      $stderr.puts("-tweetData = parseTweet(text)") if @verbose
      tweetData = parseTweet(text)
      $stderr.puts("+tweetData") if @verbose
      #$stderr.puts("stderr: rawText: #{tweetData[:textKernel]}")
      
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
                                         :profileImageUrl => tweet['profile_image_url']})
          twitterUser.save!
        rescue
          if $!.to_s =~ /^Mysql2::Error: INSERT command denied/
            return {:status => 1, :reject => "MYSQL_PERMISSIONS_ERROR", :details => $!.to_s}
          end
          return {:status => 1, :reject => "CANT_CREATE_TWITTER_USER", :details => $!.to_s}
        end
      end
      if verbose==VERBOSE_MAX
          $stderr.puts("Save tweet: text:%s(%d),user:%s, id:%s" % 
                [text, text.size, twitterUser, tweetId]) if verbose
      end
      begin
        tweet = Tweet.new({:text=>makeSafeViewableHTML(text),
                           :textKernel => tweetData[:textKernel],
                           :publishedAt=>parsedTime,
                           :twitter_user_id => twitterUser.id,
                           :sentimentScore => 0,
                           :positiveWordCount => 0,
                           :negativeWordCount => 0,
                           :tweetId=>tweetId})
      rescue
        msg = $!.to_s
        if msg != "Validation failed: Text has already been taken"
          $stderr.puts("Can't save a tweet (text:%s(%d)): %s" % [text, text.size, msg])
        end
        return {:status => 1, :reject => "TWEET_CREATION_FAILURE", :details => $!.to_s}
      end
      begin
        twitterUser.tweets << tweet
      rescue
        if $!.to_s =~ /^Mysql2::Error: INSERT command denied/
          return {:status => 1, :reject => "MYSQL_PERMISSIONS_ERROR", :details => $!.to_s}
        end
        return {:status => 1, :reject => "CANT_ASSOCIATE_TWITTER_USER", :details => $!.to_s}
      end
      begin
        candidate.tweets << tweet
      rescue
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
    
    @@tweetParser = /\A(\s*(?:(?:RT\b[\s:]*)?(?:@[a-zA-Z][\w\-.]*[,:\s]*))*)
                     (.*?)
                     ((?:http:\/\/.*?\/\S+|[\#\@][a-zA-Z][\w\-.]*|\s)*)\Z/mx
    def parseTweet(text)
      m = @@tweetParser.match(text)
      if m.nil?
        $stderr.puts("parseTweet: Failed to match text:#{text} ")
      end
      return {
        :retweet => m[1],
        :textKernel => m[2],
        :trailingTagsAndLinks => m[3]
      }
    end
  end # class
end

def runHarvest(options)
  bhc = BatchHarvester.new(options[:verbose])
  bhc.updateTweets
  lim = options[:iterations]
  if lim > 0
    sleepTime = options[:repeat] * 60
    sleepTime = 60 if sleepTime == 0
    while lim > 0
      lim -= 0
      sleep sleepTime
      bhc.updateTweets
    end
  end
end

def removeOldTweets(options)
  cutoffDate = options[:cutoffDate]
  $stderr.puts("************ removeOldTweets: cutoffDate:#{cutoffDate}")
  if cutoffDate.nil?
    cutoffDate = DateTime.now.utc - 1.month
  else
    cutoffDate = DateTime.parse(cutoffDate, true)
  end
  data = {
    :before => {
      :tweets => Tweet.count,
      :duplicates => DuplicateTweet.count,
      :twitter_users =>  TwitterUser.count,
    }
  }
  conn = Tweet.connection
  # This one's easy, as there are no dependencies:
  conn.execute("delete from duplicate_tweets
		where publishedAt < #{conn.quote(cutoffDate)}")
  rows = conn.select_rows("SELECT id, twitter_user_id from tweets
		   where publishedAt < #{conn.quote(cutoffDate)}")
  ids = rows.map {|row| row[0]}
  user_ids = rows.map {|row| row[1]}
  orig_ids = ids.clone
  while ids.size > 0
    ids_frag = ids.slice!(0, 100)
    query = (["tweet_id = %d"] * ids_frag.size).join(" or ") % ids_frag
    conn.execute("delete from candidates_tweets where " + query)
    
    query = (["orig_tweet_id = %d"] * ids_frag.size).join(" or ") % ids_frag
    conn.execute("delete from duplicate_tweets where " + query)
  end
  Tweet.delete(orig_ids)
  user_ids_to_drop = []
  while user_ids.size > 0
    user_ids_frag = user_ids.slice!(0, 100)
    query = (["twitter_user_id = %d"] * user_ids_frag.size).join(" or ") % user_ids_frag
    found_user_ids = conn.select_rows("select twitter_user_id from tweets where " + query).map{|row| row[0]}
    user_ids_to_drop += user_ids_frag - found_user_ids
  end
  TwitterUser.delete(user_ids_to_drop)
  data[:after] = {
    :tweets => Tweet.count,
    :duplicates => DuplicateTweet.count,
    :twitter_users =>  TwitterUser.count,
  }
  if options[:verbose]
    $stderr.puts("Removed #{data[:before][:tweets] - data[:after][:tweets]} tweets")
    $stderr.puts("        #{data[:before][:duplicates] - data[:after][:duplicates]} duplicates")
    $stderr.puts("        #{data[:before][:twitter_users] - data[:after][:twitter_users]} users")
  end
end
  
def readableTime(dayPart)
  numDays = dayPart.floor
  hoursPart = (dayPart - numDays) * 24
  numHours = hoursPart.floor
  minutesPart = (hoursPart - numHours) * 60
  numMinutes = minutesPart.floor
  numSeconds = ((minutesPart - numMinutes)*60).floor
  s = []
  s << "#{numDays} days" if numDays > 0
  s << "#{numHours} hours" if numHours > 0 || s.size > 0
  s << "#{numMinutes} minutes" if numMinutes > 0 || s.size > 0
  s << "#{numSeconds} seconds" if numSeconds > 0
  return s.join(", ")
  
end
def showStatus(options)
  data = {
    :tweets => Tweet.count,
    :duplicates => DuplicateTweet.count,
    :twitter_users =>  TwitterUser.count,
  }
  now = DateTime.now.utc
  relative_times = Tweet.find(:all).map { |tw|
    (now - DateTime.parse(tw.publishedAt.to_s)).to_f
  }
  maxTime = relative_times.max
  minTime = relative_times.min
  meanTime = relative_times.sum / relative_times.size
  stdDev = ((relative_times.map{|r| (r - meanTime)**2  }.sum) / relative_times.size) ** 0.5
  
  $stderr.puts("#tweets:        #{data[:tweets]}")
  $stderr.puts("#duplicates:    #{data[:duplicates]} ")
  $stderr.puts("#twitter_users: #{data[:twitter_users]} ")
  $stderr.puts("maxTime = #{readableTime(maxTime)}")
  $stderr.puts("minTime = #{readableTime(minTime)}")
  $stderr.puts("meanTime =  #{readableTime(meanTime)}")
  $stderr.puts("stdDev =  #{readableTime(stdDev)}")
end

namespace :harvest do
  desc "update tweets"
  task :update, [:verbose] => :environment do |t, args|
    options = {
      :verbose => args.verbose == "true",
      :iterations => 0,
      :repeat => 0
    }
    runHarvest options
  end
  
  desc "cull old tweets"
  task :cull, [:verbose, :cutoff] => :environment do |t, args|
    options = {
      :verbose => args.verbose  == "true",
      :cutoffDate => args.cutoff == "nil" ? nil : args.cutoff
    }
    removeOldTweets options
  end
  
  desc "show status"
  task :status => :environment do |t, args|
    options = {
    }
    showStatus options
  end
end
