# Copyright (c) 2011 ActiveState Software Inc.
# See the file LICENSE.txt for licensing information.

require 'date'

class TweetsController < ApplicationController
  # GET /tweets
  # GET /tweets.xml
  @@CANDIDATE_CUTOFF = 10
  
  #def dlog(msg)
  #  File.open("/tmp/rdbgp-debug.txt", 'a') do |fd|
  #    fd.puts("tweets_controller: #{Time.now}: #{msg}")
  #  end
  #end
  
  #def startDebugger
  #  # set rdbgpdir=<path to main Ruby debugger module, rdbgp.rb>
  #  ENV['RUBYDB_OPTS'] = 'remoteport=pacer.activestate.com:2345 LogFile=/tmp/rdbgp.txt'
  #  rdgpdir=File.dirname(File.expand_path("../../../rubylib/rdbgp.rb", __FILE__))
  #  $:.push(rdgpdir)
  #  begin
  #    dlog("About to require rdbgp")
  #    require 'rdbgp'
  #    Debugger.current_context.stop_next = 1
  #    dlog("We should stop here")
  #  rescue
  #    dlog("Failed to open rdbgp: #{$!}")
  #  end
  #  _not_used = 1
  #  File.open("/tmp/rdbgp-live.txt", 'w') do |fd|
  #    fd.puts("Are we writing to /tmp/rdbgp-live.txt? : #{_not_used}")
  #  end
  #  redirect_to :action => :index
  #end
  
  def hasOlderPosts(timeMetrics=nil)
    timeMetrics = calcTimeMetrics() if timeMetrics.nil?
    hasPrevTweet = calcHasOlderPosts(timeMetrics)
    render :text => hasPrevTweet ? 1 : 0
  end
  
  def hasNewerPosts(timeMetrics=nil)
    timeMetrics = calcTimeMetrics() if timeMetrics.nil?
    hasNextTweet = calcHasNewerPosts(timeMetrics)
    render :text => hasNextTweet ? 1 : 0
  end
  
  def calcLinkInfo(timeMetrics)
    startDate = timeMetrics[:startDate]
    delta = timeMetrics[:delta]
    endDate = timeMetrics[:endDate]
    @linkInfo = {
      :hasPrevLinks => calcHasOlderPosts(timeMetrics),
      :prevLinkStartDate => startDate - delta,
      :prevLinkEndDate => startDate,
      :hasNextLinks => calcHasNewerPosts(timeMetrics),
      :nextLinkStartDate => endDate,
      :nextLinkEndDate => endDate + delta,
    }
  end
  
  def index
    timeMetrics = calcTimeMetrics()
    @startDate = timeMetrics[:startDate]
    @endDate = timeMetrics[:endDate]
    calcLinkInfo(timeMetrics)
    conn = Tweet.connection
    @hasData = conn.select_rows("SELECT count(id) from tweets
                     where publishedAt >= #{conn.quote(@startDate)}
                           and publishedAt < #{conn.quote(@endDate)}")[0][0] > 0
    respond_to do |format|
      format.html # tweets.html.erb
      format.xml  { render :xml => {
          :startDate => @startDate,
          :endDate   => @endDate,
          :linkInfo => @linkInfo,
          :hasData => @hasData,
      }}
    end
  end

  def getChartInfo
    # This returns a big honking mess of json:
    # *intervalInfo: [{
    #   num_tweets_by_candidate: num, startDate: isoDateTime, endDate: isoDateTime,
    #   num_duplicates_by_candidate: num
    # }]
    # *candidates: [ { id:..., firstName:..., lastName:..., color:... } ]
    # *candidates_to_drop: { candidateNum: true }
    # *isoFinalEndDate: end of chart time
    # *maxSize: maxSize
    # *suggestedCandidate: id# or null
    
    timeMetrics = calcTimeMetrics()
    calcLinkInfo(timeMetrics)
    returnObj = { :linkInfo => @linkInfo }
    returnObj[:isoFinalEndDate] = endDate = timeMetrics[:endDate]
    startDate = timeMetrics[:startDate]
    delta = timeMetrics[:delta]
    intervalSize = timeMetrics[:intervalSize]
    candidates = Candidate.find(:all)
    returnObj[:candidates] = candidates.map{|c| {:id => c.id, :firstName => c.firstName, :lastName => c.lastName, :color => c.color}}
    conn = Tweet.connection
    rawTweetData = conn.select_rows("SELECT c.candidate_id, t.id, t.publishedAt
                     from tweets as t, candidates_tweets as c
                     where t.publishedAt >= #{conn.quote(startDate)}
                           and t.publishedAt < #{conn.quote(timeMetrics[:endDate])}
                           and c.tweet_id = t.id")
    baseStartDateI = startDate.to_i
    numIntervals = timeMetrics[:numIntervals]
    intervalInfo = Array.new(numIntervals)
    returnObj[:intervalInfo] = intervalInfo
    finalStartDate = startDate
    loadedTweets = {}
    
    endDate = startDate
    numTweetHashTemplate = Hash[*(candidates.map{|c| [c.id, 0]}.flatten)]
    numIntervals.times do |i|
      startDate = endDate
      endDate += intervalSize.seconds
      intervalInfo[i] = { :startDate => startDate, :endDate => endDate,
                          :num_tweets_by_candidate => numTweetHashTemplate.clone,
                          :num_duplicates_by_candidate => numTweetHashTemplate.clone,}
      loadedTweets[i] = {}#Hash.new([])
    end
    startDate = finalStartDate
    
    rawTweetData.each do |candidateNum, tweetId, publishedAt|
      pubTime = DateTime.parse(publishedAt.to_s).to_i
      interval = ((pubTime - startDate.to_i)/intervalSize.seconds).to_i
      loadedTweets[interval][candidateNum] = [] unless loadedTweets[interval].has_key?(candidateNum)
      loadedTweets[interval][candidateNum] << tweetId
      intervalInfo[interval][:num_tweets_by_candidate][candidateNum] += 1
    end
    
    numIntervals.times do |i|
      ivTweets = intervalInfo[i][:num_tweets_by_candidate]
      dupTweets = intervalInfo[i][:num_duplicates_by_candidate]
      ivTweets.keys.each do | candidateNum  |
        if loadedTweets[i].has_key?(candidateNum)
          numDuplicates = countDuplicates(loadedTweets[i][candidateNum])
          ivTweets[candidateNum] += numDuplicates
          dupTweets[candidateNum] += numDuplicates
        end
      end
    end
    
    total_num_tweets_by_candidate = Hash[candidates.map{|candidate| [candidate.id, 0]}]
    maxSize = 0
    intervalInfo.each do |iv|
      iv[:num_tweets_by_candidate].each do |candidateNum, count|
        total_num_tweets_by_candidate[candidateNum] += count
        maxSize = count if maxSize < count
      end
    end
    candidateCutoff = params[:cutoff] || @@CANDIDATE_CUTOFF
    returnObj[:candidates_to_drop] = candidates_to_drop = {}
    if candidateCutoff != "none" && total_num_tweets_by_candidate.size > candidateCutoff
      counts = total_num_tweets_by_candidate.map{|k, v| [v,k]}.sort{|a,b| a[0] <=> b[0] }
      counts.slice(0, counts.size - candidateCutoff).each do |count, candidate|
        total_num_tweets_by_candidate[candidate] = -1
        candidates_to_drop[candidate] = true
      end
      intervalInfo.each do |iv|
        iv[:num_tweets_by_candidate].keys.each do |candidate|
          if total_num_tweets_by_candidate[candidate] == -1
            iv[:num_tweets_by_candidate][candidate] = nil #!!!
          end
        end
      end
    end
    data = findSessionData
    if !data['candidateNum'].blank? && !candidates_to_drop[data['candidateNum']]
      suggestedCandidate = data['candidateNum'].to_i
    else
      suggestedCandidate = nil
    end
    returnObj[:suggestedCandidate] = suggestedCandidate
    returnObj[:maxSize] = maxSize
    #$stderr.puts(">>>> #{returnObj.to_json}")
    respond_to do |format|
      format.html { render :text => returnObj.to_json }
      format.xml  { render :xml => returnObj }
    end
  end

  def getTweets
    startDateISO = params[:startDateISO] # YYYY-MM-DD
    endDateISO = params[:endDateISO]
    candidateNum = params[:candidateNum]
    if !candidateNum
      $stderr.puts("No candidateNum --- try index")
      return index
    end
    updateSessionData(candidateNum)
    startDate = DateTime.parse(startDateISO, true)
    endDate = DateTime.parse(endDateISO, true)
    tweets = Candidate.find(candidateNum).tweets.find(:all,
      :conditions => ['publishedAt >= ? and publishedAt < ?', startDate, endDate])
    resultTweets = []
    i = 0
    tweets = tweets.select{|t| t.twitter_user_id}
    user_ids = tweets.map{|t| t.twitter_user_id}
    begin
      users = TwitterUser.find(user_ids)
    rescue ActiveRecord::RecordNotFound
      users = []
      user_ids.each do |uid|
        begin
          users << TwitterUser.find(uid)
        rescue ActiveRecord::RecordNotFound
          $stderr.puts("can't find twitter user id #{uid}")
          Tweet.delete_all(['twitter_user_id == ?', uid])
        end
      end
    end 
    h = users.inject({}){ |obj, u| obj[u.id] = u; obj}
    tweets.each do |tweet|
      # $stderr.puts("Try tweet #{i}")
      i += 1
      user = h[tweet.twitter_user_id]
      if !user
        $stderr.puts "Can't find user %d for tweet %d (candidate %d)" % [tweet.twitter_user_id, tweet.id, candidateNum]
        next
      end
      info = { 'text'  => tweet.text,
              'id'     => tweet.id, 
              'tweetID'=> tweet.tweetId,
              'name'   => user.userName,
              'img'    => user.profileImageUrl,
              'userID' => user.userId }
      resultTweets << info
    end
    # $stderr.puts("getTweets => #{resultTweets.to_json[0..78]}")
    render :text => resultTweets.to_json
    #render :text=>{:requestTag => 'getTweets' || "", :result => {:res=>42}}.to_json
  end

  @@wordScanner = /[\#]?[a-zA-Z][a-zA-Z0-9\-\'_]+/
  @@httpSplitter_1 = /(<a\b[^>]*?href=["']http:\/\/[^"' \t]+?["'][^>]*>[^<]+<\/a\s*>)/
  @@httpSplitter_2 = />([^>]+)<\/a/
  @@contractionChecker = /^(.*)(n't|'s)$/

  def getWordCloud
    # $stderr.puts("getWordCloud!")
    startDateISO = params[:startDateISO] # YYYY-MM-DD
    endDateISO = params[:endDateISO]
    candidateNum = params[:candidateNum]
    if !candidateNum
      $stderr.puts("No candidateNum --- try index")
      render :text => ''
      return
    end
    startDate = DateTime.parse(startDateISO, true)
    endDate = DateTime.parse(endDateISO, true)
    # Trying to use :condition fails in Rails 2 due to mixup between
    # DateTime and Rails' ActiveSupport::TimeWithZone, but this way works:
    # Problem: clouds get invalidated everytime a new tweet is processed in that candidate range
    wordCloud = nil
    # Reinstate this once I figure out how to invalidate the cache.
    #wordCloud = CachedCloud.find_by_startTime_and_endTime_and_candidateId(startDate, endDate, candidateNum)
    if wordCloud
      #$stderr.puts("getWordCloud: return cached words")
      render :text => wordCloud.json_word_cloud
      return
    end
    stopWords = StopWord.find(:all).map{|s|s.word}
    textBits = Candidate.find(candidateNum).tweets.find(:all,
      :conditions => ['publishedAt >= ? and publishedAt < ?', startDate, endDate]).map{|tw|tw.text}
    wordCounts = {}
    textBits.each do |textBit|
      associatedLink = nil
      links, textBitWithLinks = textBit.split(@@httpSplitter_1).partition{|frag| frag[0, 3] == "<a "}
      textBit2 = textBitWithLinks.join(" ")
      if links.size > 0
        m = @@httpSplitter_2.match(links[0])
        associatedLink = m && m[1]
      end
      words = textBit2.scan(@@wordScanner)
      numWords = words.size
      query = (["word = ?"] * numWords).join(" or ")
      words = words.reject{|wd| stopWords.index(wd.downcase)}
      words.each do |wd|
        wdl = wd.downcase
	next if (m = @@contractionChecker.match(wdl)) and stopWords.index(m[1])
        if wordCounts.has_key?(wdl)
          wordCounts[wdl]['weight'] += 1
          if !wordCounts[wdl]['url'] && associatedLink
            wordCounts[wdl]['url'] = associatedLink
          end
        else
          wordCounts[wdl] = {'text' => wd, 'weight' => 1}
          if associatedLink
            wordCounts[wdl]['url'] = associatedLink
          end
        end
      end
    end
    # Now cull it down
    wordCounts = wordCounts.values
    numWords = wordCounts.size
    limit1 = 80
    limit2 = 40
    if numWords > limit1
      wordSizeThreshold = 1
      while true
        numKeptWords = wordCounts.find_all{|info| info['weight'] > wordSizeThreshold}.size
        if numKeptWords < 40
          # $stderr.puts("Dropping to #{numKeptWords}")
          wordCounts = wordCounts.find_all{|info| info['weight'] >= wordSizeThreshold}
          break
        elsif numKeptWords < limit1
          # $stderr.puts("Dropping to 1 before #{numKeptWords}")
          wordCounts = wordCounts.find_all{|info| info['weight'] > wordSizeThreshold}
          break
        else
          wordSizeThreshold += 1
          # $stderr.puts("Try word-size threshold of #{wordSizeThreshold}")
        end
      end
    end
    sortedWordCounts = wordCounts.sort{|a, b| b['weight'] <=> a['weight'] }
    if sortedWordCounts.size > 3
      $stderr.puts("top 3 words: #{sortedWordCounts[0]['text']} - #{sortedWordCounts[0]['weight']}, "\
                   + "#{sortedWordCounts[1]['text']} - #{sortedWordCounts[1]['weight']}, "\
                   + "#{sortedWordCounts[2]['text']} - #{sortedWordCounts[2]['weight']}, " )
      # Look at combining the first two names
      name1 = sortedWordCounts[0]['text']
      name2 = sortedWordCounts[1]['text']
      if Candidate.find_by_firstName_and_lastName(name1, name2) 
          sortedWordCounts[0]['text'] = "#{name1} #{name2}"
          sortedWordCounts.slice!(1)
      elsif Candidate.find_by_firstName_and_lastName(name2, name1)
          sortedWordCounts[0]['text'] = "#{name2} #{name1}"
          sortedWordCounts.slice!(1)
      end
      # Make the name show up equal to the next one.
      sortedWordCounts[0]['weight'] = sortedWordCounts[1]['weight']
      #if sortedWordCounts[0]['weight'] > sortedWordCounts[1]['weight'] * 1.3
        #sortedWordCounts[0]['weight'] = (sortedWordCounts[1]['weight'] * 1.3 + 0.5).to_i
      # end
    end
    # $stderr.puts("Got #{sortedWordCounts.size} words to process")
    # $stderr.puts("getTweets => #{sortedWordCounts.to_json[0..78]}")
    
    retStr = sortedWordCounts.to_json
    #CachedCloud.create(:startTime=>startDate, :endTime=>endDate, :candidateId=>candidateNum,
    #                   :json_word_cloud=>retStr)
    #ccSize = CachedCloud.count
    # $stderr.puts "cache size: #{ccSize}"
    #if ccSize > 100
    #  oldRows = CachedCloud.find(:all, :order=>:startTime, :limit=>ccSize - 100)
    #  oldRows.each {|row| row.delete if row.startTime != startDate}
    #end
    render :text => retStr
  end
  
  private

  def countDuplicates(tweetIds)
    query = (['orig_tweet_id = ?'] * tweetIds.size).join(" OR ")
    return DuplicateTweet.count(:conditions => [query, *tweetIds])
  end
  
  def findSessionData
    session[:prezbuzzData] ||= {}
  end
  
  def updateSessionData(candidateNum)
    data = findSessionData
    data['candidateNum'] = candidateNum
  end
  
  def calcHasOlderPosts(timeMetrics)
    return Tweet.first(:conditions => ["publishedAt < ? ",
                                       timeMetrics[:startDate]])
  end
  
  def calcHasNewerPosts(timeMetrics)
    return Tweet.first(:conditions => ["publishedAt >= ? ",
                                       timeMetrics[:endDate]])
  end
  
  def calcTimeMetrics
    startDateISO = params[:startDateISO] # YYYY-MM-DD
    endDateISO = params[:endDateISO]
    if startDateISO.nil? || endDateISO.nil?
      now = DateTime.now.utc
      endDate = DateTime.new(now.year, now.month, now.day, now.hour) + 1.hour
      startDate = endDate - 4.hours
      numIntervals = 4
      intervalSize = 1.hour
    else
      startDate = DateTime.parse(startDateISO, true)
      endDate = DateTime.parse(endDateISO, true)
      numIntervals = 4
      intervalSize = ((endDate.to_time.to_i - startDate.to_time.to_i)/numIntervals).seconds.to_i
    end
    $stderr.puts("calcTimeMetrics: intervalSize:#{intervalSize}")
    delta = (endDate.to_i - startDate.to_i).seconds
    return {
      :startDate => startDate,
      :endDate => endDate,
      :numIntervals => numIntervals,
      :intervalSize => intervalSize,
      :delta => delta,
    }
  end

end
