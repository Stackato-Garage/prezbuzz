require 'date'

class TweetsController < ApplicationController
  # GET /tweets
  # GET /tweets.xml
  @@CANDIDATE_CUTOFF = 10
  def index
    startDateISO = params[:startDateISO] # YYYY-MM-DD
    endDateISO = params[:endDateISO]
    candidateCutoff = params[:cutoff] || @@CANDIDATE_CUTOFF
    if startDateISO.nil? || endDateISO.nil?
      now = DateTime.now.utc
      endDate = DateTime.new(now.year, now.month, now.day, now.hour) + 1.hour
      startDate = endDate - 6.hours
      numIntervals = 6
      intervalSize = 1.hour
    else
      startDate = DateTime.parse(startDateISO, true)
      endDate = DateTime.parse(endDateISO, true)
      numIntervals = 6
      intervalSize = ((endDate.to_time.to_i - startDate.to_time.to_i)/numIntervals).seconds.to_i
    end
    @isoFinalEndDate = finalEndDate = endDate
    endDate = startDate
    @intervalInfo = []
    @formatTimes = ["%b %d %Y, %I:%M %p", "%I:%M %p"]
    @candidates = Candidate.find(:all)
    @linkInfo = {}
    delta = (finalEndDate.to_i - startDate.to_i).seconds
    if Tweet.first(:conditions => ["publishedAt < ?", startDate])
      @linkInfo[:prevLinks]  = { :startDate => startDate - delta, :endDate =>  startDate}
    end
    if Tweet.first(:conditions => ["publishedAt >= ?", finalEndDate])
      @linkInfo[:nextLinks]  = { :startDate => finalEndDate, :endDate => finalEndDate + delta}
    end
    @maxSize = 0
    total_num_tweets_by_candidate = Hash.new(0)
    while true
      startDate = endDate
      endDate += intervalSize.seconds
      break if startDate >= finalEndDate
    
      # startDate and endDate are DateTime objects
      infoBlock = {}
      num_tweets_by_candidate = {}
      @candidates.each do |candidate|
        count = candidate.tweets.count(:all,
                         :conditions => ['publishedAt >= ? and publishedAt < ?',
                                         startDate, endDate])
        num_tweets_by_candidate[candidate] = count
        total_num_tweets_by_candidate[candidate] += count
        @maxSize = count if @maxSize < count
      end
      @intervalInfo.push({
        :startDate => startDate,
        :endDate => endDate,
        :num_tweets_by_candidate => num_tweets_by_candidate
      })
    end
    @candidates_to_drop = {}
    if candidateCutoff != "none" && @candidates.size > candidateCutoff
      counts = total_num_tweets_by_candidate.map{|k, v| [v,k]}.sort{|a,b| a[0] <=> b[0] }
      counts.slice(0, counts.size - candidateCutoff).each do |count, candidate|
        total_num_tweets_by_candidate[candidate] = -1
        @candidates_to_drop[candidate.id] = true
      end
      @intervalInfo.each do |iv|
        iv[:num_tweets_by_candidate].keys.each do |candidate|
          if total_num_tweets_by_candidate[candidate] == -1
            iv[:num_tweets_by_candidate][candidate] = nil #!!!
          end
        end
      end
    end
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => {
          :intervalInfo => @intervalInfo,
          :candidates => @candidates,
          :candidates_to_drop => @candidates_to_drop,
      }}
    end
  end

  def getTweets
    $stderr.puts("called getTweets!") 
    startDateISO = params[:startDateISO] # YYYY-MM-DD
    endDateISO = params[:endDateISO]
    candidateNum = params[:candidateNum]
    if !candidateNum
      $stderr.puts("No candidateNum --- try index")
      return index
    end
    startDate = DateTime.parse(startDateISO, true)
    endDate = DateTime.parse(endDateISO, true)
    tweets = Candidate.find(candidateNum).tweets.find(:all,
      :conditions => ['publishedAt >= ? and publishedAt < ?', startDate, endDate])
    $stderr.puts("Got #{tweets.size} tweets to process")
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
      $stderr.puts("Try tweet #{i}")
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
    $stderr.puts("getTweets => #{resultTweets.to_json[0..78]}")
    render :text => resultTweets.to_json
    #render :text=>{:requestTag => 'getTweets' || "", :result => {:res=>42}}.to_json
  end

  @@wordScanner = /[\#]?[a-zA-Z][a-zA-Z0-9\-\'_]+/
  @@httpSplitter_1 = /(<a\b[^>]*?href=["']http:\/\/[^"' \t]+?["'][^>]*>[^<]+<\/a\s*>)/
  @@httpSplitter_2 = />([^>]+)<\/a/
  @@contractionChecker = /^(.*)(n't|'s)$/

  def getWordCloud
    $stderr.puts("getWordCloud!")
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
    wordCloud = CachedCloud.find_by_startTime_and_endTime_and_candidateId(startDate, endDate, candidateNum)
    if wordCloud
      $stderr.puts("getWordCloud: return cached words")
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
          $stderr.puts("Dropping to #{numKeptWords}")
          wordCounts = wordCounts.find_all{|info| info['weight'] >= wordSizeThreshold}
          break
        elsif numKeptWords < limit1
          $stderr.puts("Dropping to 1 before #{numKeptWords}")
          wordCounts = wordCounts.find_all{|info| info['weight'] > wordSizeThreshold}
          break
        else
          wordSizeThreshold += 1
          $stderr.puts("Try word-size threshold of #{wordSizeThreshold}")
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
      if sortedWordCounts[0]['weight'] > sortedWordCounts[1]['weight'] * 1.3
        sortedWordCounts[0]['weight'] = (sortedWordCounts[1]['weight'] * 1.3 + 0.5).to_i
      end
    end
    $stderr.puts("Got #{sortedWordCounts.size} words to process")
    $stderr.puts("getTweets => #{sortedWordCounts.to_json[0..78]}")
    
    retStr = sortedWordCounts.to_json
    CachedCloud.create(:startTime=>startDate, :endTime=>endDate, :candidateId=>candidateNum,
                       :json_word_cloud=>retStr)
    ccSize = CachedCloud.count
    $stderr.puts "cache size: #{ccSize}"
    if ccSize > 100
      oldRows = CachedCloud.find(:all, :order=>:startTime, :limit=>ccSize - 100)
      oldRows.each {|row| row.delete if row.startTime != startDate}
    end
    render :text => retStr
  end

  def indexFullTweets
    startDateISO = params[:startDateISO] # YYYY-MM-DD
    endDateISO = params[:endDateISO]
    @tweets = Tweet.all
    if startDateISO.nil? || endDateISO.nil?
      now = DateTime.now.utc
      endDate = DateTime.new(now.year, now.month, now.day, now.hour) + 1.hour
      startDate = endDate - 6.hours
      numIntervals = 6
      intervalSize = 1.hour
    else
      startDate = DateTime.parse(startDateISO, true)
      endDate = DateTime.parse(endDateISO, true)
      numIntervals = 6
      intervalSize = (endDate.to_i - startDate.to_i).seconds
    end
    finalEndDate = endDate
    endDate = startDate
    @intervalInfo = []
    @username_from_tweet = {}
    @candidates = Candidate.find(:all)
    while true
      startDate = endDate
      endDate += intervalSize
      break if startDate >= finalEndDate
    
      # startDate and endDate are DateTime objects
      infoBlock = {}
      tweets_by_candidate = {}
      @candidates.each do |candidate|
        tweets_by_candidate[candidate] = candidate.tweets.find(:all,
                         :conditions => ['publishedAt >= ? and publishedAt < ?',
                                         startDate, endDate])
        tweets_by_candidate[candidate].each do |tweet|
          @username_from_tweet[tweet.id] = begin TwitterUser.find(tweet.twitter_user_id).userName rescue $! end
        end
      end
      @intervalInfo.push({
        :startDate => startDate,
        :endDate => endDate,
        :tweets_by_candidate => tweets_by_candidate
      })
    end
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @tweets }
    end
  end

  # GET /tweets/1
  # GET /tweets/1.xml
  def show
    id = params[:id]
    if id == "getWordCloud"
      getWordCloud
      return
    elsif id == "getTweets"
      getTweets
      return
    end
    @tweet = Tweet.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @tweet }
    end
  end
  ####
  ##### GET /tweets/new
  ##### GET /tweets/new.xml
  ####def new
  ####  @tweet = Tweet.new
  ####
  ####  respond_to do |format|
  ####    format.html # new.html.erb
  ####    format.xml  { render :xml => @tweet }
  ####  end
  ####end
  ####
  ##### GET /tweets/1/edit
  ####def edit
  ####  @tweet = Tweet.find(params[:id])
  ####end
  ####
  ##### POST /tweets
  ##### POST /tweets.xml
  ####def create
  ####  @tweet = Tweet.new(params[:tweet])
  ####
  ####  respond_to do |format|
  ####    if @tweet.save
  ####      format.html { redirect_to(@tweet, :notice => 'Tweet was successfully created.') }
  ####      format.xml  { render :xml => @tweet, :status => :created, :location => @tweet }
  ####    else
  ####      format.html { render :action => "new" }
  ####      format.xml  { render :xml => @tweet.errors, :status => :unprocessable_entity }
  ####    end
  ####  end
  ####end
  ####
  ##### PUT /tweets/1
  ##### PUT /tweets/1.xml
  ####def update
  ####  @tweet = Tweet.find(params[:id])
  ####
  ####  respond_to do |format|
  ####    if @tweet.update_attributes(params[:tweet])
  ####      format.html { redirect_to(@tweet, :notice => 'Tweet was successfully updated.') }
  ####      format.xml  { head :ok }
  ####    else
  ####      format.html { render :action => "edit" }
  ####      format.xml  { render :xml => @tweet.errors, :status => :unprocessable_entity }
  ####    end
  ####  end
  ####end
  ####
  ##### DELETE /tweets/1
  ##### DELETE /tweets/1.xml
  ####def destroy
  ####  @tweet = Tweet.find(params[:id])
  ####  @tweet.destroy
  ####
  ####  respond_to do |format|
  ####    format.html { redirect_to(tweets_url) }
  ####    format.xml  { head :ok }
  ####  end
  ####end
end
