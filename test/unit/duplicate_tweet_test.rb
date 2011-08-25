require 'test_helper'

class DuplicateTweetTest < ActiveSupport::TestCase
  fixtures [:tweets, :duplicate_tweets]
  
  test "duplicated intervals 1" do
    # No usable duplicates in this interval
    candidateNum = 1
    startDateISO = "2011-08-24 19:05:00 UTC"
    endDateISO   = "2011-08-24 19:10:00 UTC"
    startDate = DateTime.parse(startDateISO, true)
    endDate   = DateTime.parse(endDateISO, true)
    tweets = Candidate.find(candidateNum).tweets.find(:all,
      :conditions => ['publishedAt >= ? and publishedAt < ?', startDate, endDate])
    origExpAmt = 11 - 5 + 1
    assert tweets.size == origExpAmt, "expected to see #{origExpAmt} tweets in interval, got #{tweets.size}"
    conn = Tweet.connection
    duplicateIDs = conn.select_rows("SELECT d.orig_tweet_id 
                                      from duplicate_tweets as d, candidates_tweets as c
                                      where c.candidate_id = #{candidateNum}
                                            and d.publishedAt >= #{conn.quote(startDate)}
                                            and d.publishedAt < #{conn.quote(endDate)}
                                            and c.tweet_id = d.orig_tweet_id").map{|r|r[0]}
    assert duplicateIDs.size == 1, "expected 1 dup, got #{duplicateIDs.size}"
    origIDs = Hash[*tweets.map{|t| [t.id, true]}.flatten]
    assert !origIDs.has_key?(duplicateIDs[0]), "unexpected: origIDs has key #{duplicateIDs[0]}"
    assert duplicateIDs[0] == 4, "expected duplicate tweet => 4, got #{duplicateIDs[0]}"
  end
  
  test "duplicated intervals 2" do
    # This time we have some duplicates to keep, some to drop
    candidateNum = 1
    startDateISO = "2011-08-24 18:45:00 UTC"
    endDateISO   = "2011-08-24 19:00:00 UTC"
    startDate = DateTime.parse(startDateISO, true)
    endDate   = DateTime.parse(endDateISO, true)
    tweets = Candidate.find(candidateNum).tweets.find(:all,
      :conditions => ['publishedAt >= ? and publishedAt < ?', startDate, endDate])
    origExpAmt = 50 - 23 + 1
    assert tweets.size == origExpAmt, "expected to see #{origExpAmt} tweets in interval, got #{tweets.size}"
    origIDs = Hash[*tweets.map{|t| [t.id, true]}.flatten]
    conn = Tweet.connection
    duplicateIDs = conn.select_rows("SELECT d.orig_tweet_id 
                                      from duplicate_tweets as d, candidates_tweets as c
                                      where c.candidate_id = #{candidateNum}
                                            and d.publishedAt >= #{conn.quote(startDate)}
                                            and d.publishedAt < #{conn.quote(endDate)}
                                            and c.tweet_id = d.orig_tweet_id").flatten
    expDupAmt = 3
    assert duplicateIDs.size == expDupAmt, "expected #{expDupAmt} dups, got #{duplicateIDs.size}"
    duplicateIDs.sort!
    assert duplicateIDs[0] == 10
    assert duplicateIDs[1] == 30
    assert duplicateIDs[2] == 41
    assert !origIDs.has_key?(duplicateIDs[0]), "unexpected: origIDs has key #{duplicateIDs[0]}"
    assert origIDs.has_key?(duplicateIDs[1]), "unexpected: origIDs hasnt key #{duplicateIDs[1]}"
    assert origIDs.has_key?(duplicateIDs[2]), "unexpected: origIDs hasnt key #{duplicateIDs[2]}"
  end
end
