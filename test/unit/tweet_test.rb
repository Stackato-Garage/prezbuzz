require File.dirname(__FILE__) + '/../test_helper'

class TweetTest < ActiveSupport::TestCase
  fixtures :tweets
  
  test "item 1" do
    c = Tweet.find(1)
    assert c.tweetId == "106444081852465152"
    bit = "Bruh we are Barack"
    assert c.text[0 .. bit.size - 1] == bit, "Failed to match #{c.text}, got bit #{c[0 .. bit.size - 1]}"
    rawTime = "2011-08-24 19:13:41 UTC"
    parsedTime = Time.zone.parse(rawTime)
    assert c.publishedAt == parsedTime, "Failed to match pub date: #{c.publishedAt} (#{c.publishedAt.class})"
  end
  
  test "intervals 1" do
    candidateNum = 1
    startDateISO = "2011-08-24 19:10:00 UTC"
    endDateISO = "2011-08-24 19:15:00 UTC"
    startDate = DateTime.parse(startDateISO, true)
    endDate = DateTime.parse(endDateISO, true)
    tweets = Candidate.find(candidateNum).tweets.find(:all,
      :conditions => ['publishedAt >= ? and publishedAt < ?', startDate, endDate])
    assert tweets.size == 4, "expected to see 4 tweets in interval, got #{tweets.size}"
    origIDs = Hash[*tweets.map{|t| [t.id, true]}.flatten]
    conn = Tweet.connection
    duplicateIDs = conn.select_rows("SELECT d.orig_tweet_id 
                                      from duplicate_tweets as d, candidates_tweets as c
                                      where c.candidate_id = #{candidateNum}
                                            and d.publishedAt >= #{conn.quote(startDate)}
                                            and d.publishedAt < #{conn.quote(endDate)}
                                            and c.tweet_id = d.orig_tweet_id").flatten
    assert duplicateIDs.size == 0, "expected 0 dups, got #{duplicateIDs.size}"
  end
  test "intervals 2" do
    candidateNum = 1
    startDateISO = "2011-08-24 18:40:00 UTC"
    endDateISO = "2011-08-24 18:45:00 UTC"
    startDate = DateTime.parse(startDateISO, true)
    endDate = DateTime.parse(endDateISO, true)
    tweets = Candidate.find(candidateNum).tweets.find(:all,
      :conditions => ['publishedAt >= ? and publishedAt < ?', startDate, endDate])
    assert tweets.size == 0, "expected to see 0 tweets in interval, got #{tweets.size}"
    origIDs = Hash[*tweets.map{|t| [t.id, true]}.flatten]
    conn = Tweet.connection
    duplicateIDs = conn.select_rows("SELECT d.orig_tweet_id 
                                      from duplicate_tweets as d, candidates_tweets as c
                                      where c.candidate_id = #{candidateNum}
                                            and d.publishedAt >= #{conn.quote(startDate)}
                                            and d.publishedAt < #{conn.quote(endDate)}
                                            and c.tweet_id = d.orig_tweet_id").flatten
    assert duplicateIDs.size == 1, "expected 1 dups, got #{duplicateIDs.size}"
  end
end

class Holder

def y(name, idx)
  dent = " " * 8
  tw = Tweet.find(idx)
  text = tw.text
  if text["\n"]
    text = ">\n" + dent + text.gsub(/(?:\r?\n)+/, "\n" + dent)
  else
    text = '"' + text.gsub('\\', '\\\\').gsub('"', '\\"') + '"'
  end
  puts "#{name}#{idx}:
    id: #{tw.id}
    text: #{text}
    tweetId: #{tw.tweetId}
    publishedAt: #{tw.publishedAt}
    twitter_user_id: #{tw.twitter_user_id}

"
end

50.times do |i| idx = i + 1; y("i", idx); end ; 33


def dump_duplicates(items, prefix="i")
  num = 0
  items.each do |item|
    num += 1
    puts "#{prefix}#{num}:
    id: #{item.id}
    orig_tweet_id: #{item.orig_tweet_id}
    tweetId: #{item.tweetId}
    publishedAt: #{item.publishedAt}

"
  end
end

def dumpCandidates(cs)
  cs.each do |c|
    puts "#{c.lastName.downcase}:
    id: #{c.id}
    lastName: #{c.lastName}
    firstName: #{c.firstName}
    color: #{c.color}

"
  end
end


def dumpCandidateTweets(cs, cand_id, name="i", starting_idx=1)
  idx = starting_idx
  cs.each do |c|
    puts "#{name}#{idx}:
    candidate_id: #{cand_id}
    tweet_id: #{c.tweet_id}

"
    idx += 1
  end
end

def dumpTwitterUsers(cs, name="tu", starting_idx=1)
  idx = starting_idx
  cs.each do |c|
    puts "#{name}#{idx}:
    id: #{c.id}
    userName: #{c.userName}
    userId: #{c.userId}
    profileImageUrl: \"#{c.profileImageUrl}\"

"
    idx += 1
  end
end

dumpTwitterUsers(TwitterUser.find(:all, :conditions => "id <= 50")); 33

end
