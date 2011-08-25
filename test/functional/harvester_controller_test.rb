require 'test_helper'
require "harvester_controller"

class HarvesterController
  def rescue_action(e)
    raise e
  end
end

class HarvesterControllerTest < ActionController::TestCase
  fixtures :tweets, :twitter_users, :duplicate_tweets
  test "remove too old" do
    xhr(:get, :removeOldTweets,
        :cutoffDate => "2011-08-24T08:40:00")
      assert_response :success
      #assert @response.body == "x", @response.body
      obj = ActiveSupport::JSON.decode @response.body
      beforeParts = obj['before']
      afterParts = obj['after']
      assert beforeParts['tweets'] == afterParts['tweets'], "tweets: #{beforeParts['tweets'] - afterParts['tweets']}"
      assert beforeParts['duplicates'] == afterParts['duplicates'], "duplicates: #{beforeParts['duplicates'] - afterParts['duplicates']}"
      assert beforeParts['twitter_users'] == afterParts['twitter_users'], "twitter_users: #{beforeParts['twitter_users'] - afterParts['twitter_users']}"
  end
  test "remove just before oldest" do
    xhr(:get, :removeOldTweets,
        :cutoffDate => "2011-08-24 18:37:04")
      assert_response :success
      obj = ActiveSupport::JSON.decode @response.body
      beforeParts = obj['before']
      afterParts = obj['after']
      assert beforeParts['tweets'] == afterParts['tweets'], "tweets: #{beforeParts['tweets'] - afterParts['tweets']}"
      assert beforeParts['duplicates'] == afterParts['duplicates'], "duplicates: #{beforeParts['duplicates'] - afterParts['duplicates']}"
      assert beforeParts['twitter_users'] == afterParts['twitter_users'], "twitter_users: #{beforeParts['twitter_users'] - afterParts['twitter_users']}"
  end
  test "remove oldest duplicate" do
    xhr(:get, :removeOldTweets,
        :cutoffDate => "2011-08-24 18:37:05")
      assert_response :success
      obj = ActiveSupport::JSON.decode @response.body
      beforeParts = obj['before']
      afterParts = obj['after']
      assert beforeParts['tweets'] == afterParts['tweets'], "tweets: #{beforeParts['tweets'] - afterParts['tweets']}"
      assert beforeParts['duplicates'] - 1 == afterParts['duplicates'], "duplicates: #{beforeParts['duplicates'] - afterParts['duplicates']}"
      assert beforeParts['twitter_users'] == afterParts['twitter_users'], "twitter_users: #{beforeParts['twitter_users'] - afterParts['twitter_users']}"
  end
  # Finally verify dependent users are deleted
  test "remove a bunch of items" do
    xhr(:get, :removeOldTweets,
        :cutoffDate => "2011-08-24 19:05:00")
      assert_response :success
      obj = ActiveSupport::JSON.decode @response.body
      beforeParts = obj['before']
      afterParts = obj['after']
      # The reason why we end up with 13 users is because one of the
      # users isn't referenced in any tweets, but we don't track those here.
      assert afterParts['tweets'] == 11, "tweets: #{afterParts['tweets']}"
      assert afterParts['duplicates'] == 1, "duplicates: #{afterParts['duplicates']}"
      assert afterParts['twitter_users'] == 13, "twitter_users: #{afterParts['twitter_users']}"
  end
end