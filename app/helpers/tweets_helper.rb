module TweetsHelper
  def getUserName(tweet)
    begin
      $stderr.puts(">> getUserName(#{tweet.twitter_user_id})")
      return TwitterUser.get(tweet.twitter_user_id).userName
    rescue
      $stderr.find("Yowp -- can't get a user for tweet #{tweet.id}: #{$!}")
      return ""
    end
  end
end
