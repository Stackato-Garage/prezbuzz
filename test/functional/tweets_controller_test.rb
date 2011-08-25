require 'test_helper'
require "tweets_controller"

class TweetsController
  def rescue_action(e)
    raise e
  end
end

class TweetsControllerTest < ActionController::TestCase
  fixtures :tweets, :twitter_users, :duplicate_tweets
  test "getChartInfo 1" do
    xhr(:get, :getChartInfo,
        :startDateISO => "2011-08-24T18:40:00",
        :endDateISO   => "2011-08-24T19:00:00")
    assert_response :success
    obj = ActiveSupport::JSON.decode @response.body
    assert obj['isoFinalEndDate'] == "2011-08-24T19:00:00+00:00"
    intervalInfo = obj['intervalInfo']
    iv0 = intervalInfo[0]
    assert iv0['startDate'] == "2011-08-24T18:40:00+00:00"
    assert iv0['endDate']   == "2011-08-24T18:45:00+00:00"
    expDup = 1
    expCount = expDup + 0
    assert iv0['num_tweets_by_candidate']["1"] == expCount, "expected #{expCount} tweet(s), got #{iv0['num_tweets_by_candidate']["1"]}"
    assert iv0['num_duplicates_by_candidate']["1"] == expDup, "expected #{expDup} dup(s), got #{iv0['num_duplicates_by_candidate']["1"]}"
    
    iv0 = intervalInfo[1]
    assert iv0['startDate'] == "2011-08-24T18:45:00+00:00"
    assert iv0['endDate']   == "2011-08-24T18:50:00+00:00"
    expDup = 1
    expCount = expDup + 50 - 41 + 1 + 1 # Move id 10 into regular for this frame
    assert iv0['num_tweets_by_candidate']["1"] == expCount, "expected #{expCount} tweet(s), got #{iv0['num_tweets_by_candidate']["1"]}"
    assert iv0['num_duplicates_by_candidate']["1"] == expDup, "expected #{expDup} dup(s), got #{iv0['num_duplicates_by_candidate']["1"]}"
    
    iv0 = intervalInfo[2]
    assert iv0['startDate'] == "2011-08-24T18:50:00+00:00"
    assert iv0['endDate']   == "2011-08-24T18:55:00+00:00"
    expDup = 0
    expCount = expDup + 40 - 38 + 1
    assert iv0['num_tweets_by_candidate']["1"] == expCount, "expected #{expCount} tweet(s), got #{iv0['num_tweets_by_candidate']["1"]}"
    assert iv0['num_duplicates_by_candidate']["1"] == expDup, "expected #{expDup} dup(s), got #{iv0['num_duplicates_by_candidate']["1"]}"
    
    iv0 = intervalInfo[3]
    assert iv0['startDate'] == "2011-08-24T18:55:00+00:00"
    assert iv0['endDate']   == "2011-08-24T19:00:00+00:00"
    expDup = 1
    expCount = expDup + 37 - 23 + 1 
    assert iv0['num_tweets_by_candidate']["1"] == expCount, "expected #{expCount} tweet(s), got #{iv0['num_tweets_by_candidate']["1"]}"
    assert iv0['num_duplicates_by_candidate']["1"] == expDup, "expected #{expDup} dup(s), got #{iv0['num_duplicates_by_candidate']["1"]}"
    
    #assert @response.body == "", @response.body
  end
  
  test "getChartInfo 2" do
    xhr(:get, :getChartInfo,
        :startDateISO => "2011-08-24T18:30:00",
        :endDateISO   => "2011-08-24T19:10:00")
    assert_response :success
    obj = ActiveSupport::JSON.decode @response.body
    intervalInfo = obj['intervalInfo']
    iv0 = intervalInfo[0]
    assert iv0['startDate'] == "2011-08-24T18:30:00+00:00"
    assert iv0['endDate']   == "2011-08-24T18:40:00+00:00"
    expDup = 2
    expCount = expDup  # dup 56 doesn't show because there's no tweet for it
    assert iv0['num_tweets_by_candidate']["1"]     == expCount, "expected #{expCount} tweet(s), got #{iv0['num_tweets_by_candidate']["1"]}"
    assert iv0['num_duplicates_by_candidate']["1"] == expDup,   "expected #{expDup} dup(s), got #{iv0['num_duplicates_by_candidate']["1"]}"
    
    iv0 = intervalInfo[1]
    assert iv0['startDate'] == "2011-08-24T18:40:00+00:00"
    assert iv0['endDate']   == "2011-08-24T18:50:00+00:00"
    expDup = 3
    expCount = expDup + 50 - 41 + 1
    assert iv0['num_tweets_by_candidate']["1"]     == expCount, "expected #{expCount} tweet(s), got #{iv0['num_tweets_by_candidate']["1"]}"
    assert iv0['num_duplicates_by_candidate']["1"] == expDup,   "expected #{expDup} dup(s), got #{iv0['num_duplicates_by_candidate']["1"]}"
    
    iv0 = intervalInfo[2]
    assert iv0['startDate'] == "2011-08-24T18:50:00+00:00"
    assert iv0['endDate']   == "2011-08-24T19:00:00+00:00"
    expDup = 1
    expCount = expDup + 40 - 23 + 1
    assert iv0['num_tweets_by_candidate']["1"]     == expCount, "expected #{expCount} tweet(s), got #{iv0['num_tweets_by_candidate']["1"]}"
    assert iv0['num_duplicates_by_candidate']["1"] == expDup,   "expected #{expDup} dup(s), got #{iv0['num_duplicates_by_candidate']["1"]}"
    
    iv0 = intervalInfo[3]
    assert iv0['startDate'] == "2011-08-24T19:00:00+00:00"
    assert iv0['endDate']   == "2011-08-24T19:10:00+00:00"
    expDup = 2
    expCount = expDup + 22 - 5 + 1 + 1 # Move one of two id 4's into regular for this frame
    assert iv0['num_tweets_by_candidate']["1"]     == expCount, "expected #{expCount} tweet(s), got #{iv0['num_tweets_by_candidate']["1"]}"
    assert iv0['num_duplicates_by_candidate']["1"] == expDup,   "expected #{expDup} dup(s), got #{iv0['num_duplicates_by_candidate']["1"]}"
    
    #assert @response.body == "", @response.body
  end
  
  test "getTweets 1" do
    # This one picks a range with no duplicates
    xhr(:get, :getTweets,
        :candidateNum => 1,
        :startDateISO => "2011-08-24T19:10:00+00:00",
        :endDateISO   => "2011-08-24T19:15:00+00:00")
    assert_response :success
    tweets = ActiveSupport::JSON.decode @response.body
    assert tweets.size == 4, "Expected 4 tweets, got #{tweets.size}"
    tw0 = tweets.find{|tw| tw['id'] == 1}
    assert tw0['tweetID'] == "106444081852465152", "tw0['tweetID']:#{tw0['tweetID']}"
    
    assert !tweets.find{|tw| tw['id'] > 4}, "Found a tweet.id > 4"
  end
  test "getTweets 2" do
    # This one picks a range with in-range duplicates
    xhr(:get, :getTweets,
        :candidateNum => 1,
        :startDateISO => "2011-08-24T18:55:00+00:00",
        :endDateISO   => "2011-08-24T19:00:00+00:00")
    assert_response :success
    tweets = ActiveSupport::JSON.decode @response.body
    expCount = 37 - 23 + 1
    assert tweets.size == expCount, "Expected #{expCount} tweets, got #{tweets.size}"
    tw0 = tweets.find{|tw| tw['id'] == 23}
    assert tw0['tweetID'] == "106440615679631361", "tw0['tweetID']:#{tw0['tweetID']}"
  end
  
  test "getTweets 3" do
    # This one picks a range with duplicates pointing to other ranges
    xhr(:get, :getTweets,
        :candidateNum => 1,
        :startDateISO => "2011-08-24T18:45:00+00:00",
        :endDateISO   => "2011-08-24T18:55:00+00:00")
    assert_response :success
    tweets = ActiveSupport::JSON.decode @response.body
    expCount = 50 - 38 + 1 + 1 # Include dup for tweet #10
    assert tweets.size == expCount, "Expected #{expCount} tweets, got #{tweets.size}"
  end
  
  test "getWordCloud 1" do
    # Pick a one-duplicate range
    xhr(:get, :getWordCloud,
        :candidateNum => 1,
        :startDateISO => "2011-08-24T18:40:00+00:00",
        :endDateISO   => "2011-08-24T18:45:00+00:00")
    assert_response :success
    s = %{RT @dentay85: Pictures of Barack Obama and Rick Perry at the age of 22: Pictures of Barack Obama and Rick Perry at the age of ... <a href=\"http://t.co/5Sl7S0z\" target=\"_blank\">http://t.co/5Sl7S0z</a>}
    expURL = "http://t.co/5Sl7S0z"
    wordItems = ActiveSupport::JSON.decode @response.body
    assert wordItems.all?{|item| item['url'] == expURL}, "Not all items point to URL #{expURL}"
    newDict = Hash[*wordItems.map{|wi| [wi["text"], wi["weight"]]}.flatten]
    assert newDict['Pictures'] == 2
    assert newDict['Barack'] == 2
    assert newDict['Obama'] == 2
    assert !newDict.has_key?('Barack Obama'), "got it without enough tweets?"
  end
  
  test "getWordCloud 2" do
    # Verify we get the full name put together.
    xhr(:get, :getWordCloud,
        :candidateNum => 1,
        :startDateISO => "2011-08-24T18:30:00+00:00",
        :endDateISO   => "2011-08-24T19:00:00+00:00")
    assert_response :success
    wordItems = ActiveSupport::JSON.decode @response.body
    assert wordItems.size >= 50, "Only got #{wordItems.size} words"
    w0 = wordItems[0]
    assert w0['text'] == 'Barack Obama', "first text item is #{ w0['text']}"
  end
end
