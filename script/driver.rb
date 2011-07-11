# Copyright (c) 2011 ActiveState Software Inc.
# See the file LICENSE.txt for licensing information.

require 'net/http'
require 'uri'
require 'cgi'
begin
  require 'json'
rescue LoadError
  require 'rubygems'
  require 'json'
end

class Wrapper
  attr_reader :tweets, :numCandidates, :candidateID, :lastStopTime
  def initialize(host, port, verbose=false)
    @verbose = verbose
    @nextPage = nil
    @problemCount = 0
    @host = host
    @port = port
  end
  
  def http_get(path, params=nil)
    http = Net::HTTP.new(@host, @port)
    begin
      return http.get("#{path}?".concat(params.collect { |k,v| "#{k}=#{CGI::escape(v.to_s)}" }.join('&'))) if not params.nil?
      return http.get(path)
    rescue
      $stderr.puts "Error in http_get #{@host}:#{@port}#{path}: #{$!}"
      raise
    end 
  end
  
  def initApp
    res = http_get('/harvester/initApp')
    return res.body
  end

  def setup1
    res = http_get('/harvester/getNumberOfCandidates')
    if res.code == "404"
      raise("Error: #{@host}:#{@port} is unreachable")
    end
    @numCandidates = res.body.to_i
    res = http_get('/harvester/getFirstCandidateID')
    @candidateID = res.body
    stopTime = http_get('/harvester/getLastStopTime').body
    @lastStopTime = (stopTime.nil? || stopTime.size == 0) ? 0 : stopTime
  end
  
  def getTweetsForCurrentCandidate
    while true
      begin
        getTweets or break
      rescue
        $stderr.puts("Error getting tweets for candidate: #{@candidateID}, nextPage:{#nextPage}: #{$!}")
        return
      end 
      updateCurrentTweets or break
      if @nextPage.nil? || !@nextPage.index("page=20").nil?
        break
      end
      sleep 3
    end
  end
  
  def runThroughCandidates
    while true
      begin
        getTweetsForCurrentCandidate
      rescue
        $stderr.puts "runThroughCandidates: getTweetsForCurrentCandidate: error: #{$!}"
      end
      params = { :candidateID => @candidateID }
      begin
        res = http_get('/harvester/getNextCandidateID', params)
      rescue
        $stderr.puts "runThroughCandidates: /harvester/getNextCandidateID: error: #{$!}"
        exit
      end
      id = res.body.to_i
      break if id == -1
      @nextPage = nil
      @candidateID = id
    end
  end
  
  def getTweets
    params = { :candidateID => @candidateID,
               :verbose => @verbose}
    params[:nextPageURL] = @nextPage if @nextPage
    res = http_get('/harvester/getTweets', params)
    begin
      @searchResult = JSON.parse(res.body)
      @nextPage = @searchResult['next_page']
      if @verbose
          $stderr.puts("@searchResult: #{res.body.size} chars, @nextPage: #{@nextPage}")
      end
      @tweets = @searchResult['results']
      @tweetIdx = 0
      @tweetLimit = @tweets.size
      true
    rescue
      @problemCount += 1
      $stderr.puts("Problem parsing getTweets result: #{res.body}")
      if @problemCount >= 10
          $stderr.puts("Bailing out early")
	  exit
      end
      false
    end
  end
  
  # Move more work from the server to the client, due to timeout issues.
  
  def updateCurrentTweets
    num_successes = 0
    while @tweetIdx < @tweetLimit
      tweet = @tweets[@tweetIdx]
      tweetText = tweet['text']
      @tweetIdx += 1
      params = {:candidateID => @candidateID,
                              :lastStopTime => @lastStopTime,
                              :text => tweetText,
                              :verbose => @verbose}
      %W/created_at from_user_id_str from_user profile_image_url id/.each do |s|
        params[s] = tweet[s]
      end
      response = http_get("/harvester/updateTweet", params)
      resp = JSON.parse(response.body)
      if resp['status'] == 0 # tweetText 
        num_successes += 1
      else
	if @verbose
	    $stderr.puts("problem updating tweet #{tweetText}: #{response.body}")
	end
	if response.body['reject'] == "MYSQL_PERMISSIONS_ERROR"
	  return false
	end
      end
      if @tweetIdx % 10 == 0
          sleep 1
	  # Give nginx a break?
      end
    end
    return num_successes > 0
  end
  
  def updateLastStopTime
    response = http_get("/harvester/updateLastStopTime", nil)
  end
end

if __FILE__ == $0
  require 'optparse'
  options = {:verbose=>false,
	     :host => 'localhost',
	     :port => 80}
  OptionParser.new do |opts|
    opts.banner = "Usage: $0 [options] (init|update)"
    opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
      options[:verbose] = v
    end
    opts.on("-h", "--host HOSTNAME", "Host") do |host|
      options[:host] = host
    end
    opts.on("-p", "--port PORT", "Port") do |port|
      options[:port] = port
    end
  end.parse!

  w = Wrapper.new(options[:host], options[:port], options[:verbose])
  #print "ARGV:" ; p ARGV ; print "\n"
  #print "options:" ; p options ; print "\n"
  case  ARGV[0]
  when "init", "initApp"
    res = w.initApp
    puts res
  when "update"
    w.setup1
    w.runThroughCandidates
    w.updateLastStopTime
  end
end
