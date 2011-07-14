# Prezbuzz

Prezbuzz is a Rails 3.0 application that tracks the twitter activity
related to the candidates running for the American 2012 Presidential Election.

See LICENSE.txt for the license on PrezBuzz

To get Prezbuzz working, it needs to be deployed, initialized, and
then updated on a regular basis. This README covers running it on bare
hardware (e.g. your workstation) and deploying it to Stackato.

## Prerequisities:

You'll need Ruby (1.8.7 or 1.9.2), Rails 3.0, and rake 0.9.2 or later
installed. We recommend installing a Ruby sandbox using rvm

    ($ bash < <(curl -s https://rvm.beginrescueend.com/install/rvm))
    
This command might fail due to certificate issues.  If so, try adding the -k
flag to curl, or downloading the script separately, and handing it to bash locally.
    
    . ~/.bashrc   # Add rvm to your path
    
    rvm install 1.9.2 
    rvm list
    rvm use 1.9.2  # Or whichever is closest to the 1.9.2 you installed
    gem install rails --version=3.0.0
    
or find out more at <https://rvm.beginrescueend.com/>.

Change to the directory that contains this file, and pull down
any other required gems:

    bundle install
    
## To run the app locally:

The app is configured to run with mysql. To run with sqlite3
locally (during testing), change the development section in
config/database.yml to the following (assuming that you have
sqlite3 and the ruby adapter installed on your system):

    adapter: sqlite3
    database: dv/development.sqlite3
    pool: 5
    timeout: 5000

Initialize the database:

    rake db:migrate
    
If you get this error message:

    (in /home/ericp/lab/rails/rails3/prezbuzz-work/stackato-samples/ruby/rails3-prezbuzz)
    rake aborted!
    uninitialized constant Rake::DSL
    
...install a newer rake:

    gem install rake -v=0.9.2
    
When you run `rake db:migrate`, you should see this warning:

    WARNING: Global access to Rake DSL methods is deprecated.  Please include
        ...  Rake::DSL into classes and modules which use the Rake DSL methods.
    WARNING: DSL method Prezbuzz::Application#task called at /home/user/opt/ruby-1.9.2-p136/lib/ruby/gems/1.9.1/gems/railties-3.0.0/lib/rails/application.rb:214:in

followed by this expected output:

    ==  CreateTweets: migrating ===================================================
    -- create_table(:tweets)
       -> 0.0017s
    -- add_index(:tweets, :publishedAt)
       -> 0.0006s
    ==  CreateTweets: migrated (0.0027s) ==========================================
    ...
    
Start the server:

    rails server webrick
    
Change to another console, in the same directory, with the same
environment, and start interacting with the server.

If you've modified the list of candidates, or their colors, you'll need to
rebuild the CSS file:

    curl 'http://localhost:3000/stylesheets/rcss?rcss=candidateBuzz' > public/stylesheets/candidateBuzz.css
    
Now populate the database:

    ruby script/driver.rb -h localhost -p 3000 update -v

If it's slow, keep in mind that sqlite3 is a few orders of
magnitude slower than a networked database.

If you change the candidates' colors, or add/remove candidates, you'll
need to rebuild candidates.css, like so:

   curl 'http://localhost:3000/stylesheets/rcss?rcss=candidateBuzz' > public/stylesheets/candidateBuzz.css

This will need to be done on the server as well.

## Deploy to Stackato:

In the top-level directory of the project, run:

    stackato push prezbuzz

When prompted, choose "y" to bind a MySQL service to the app and accept
the default service name.
    
### Set database tables to use UTF-8

Change the default character set for MySQL tables to accomodate UTF-8
twitter data: 
    
    stackato dbshell prezbuzz
    > ALTER TABLE tweets CONVERT TO CHARACTER SET utf8 collate utf8_unicode_ci;
    > quit
 
### Populate/Update twitter data:

The current implementation of Prezbuzz requires data updates to be
initiated remotely. A local 'driver' script contacts the application and
gets it to fetch a new batch of tweets.

    ruby script/driver -h <hostname> update

This is best run as part of a cron job once every hour or two.

### Test the app in a browser:

With a micro-cloud deployment of Stackato, the default URL would be:

  http://prezbuzz.stackato.local
  
A hosted version of the same app can be found here:

  http://prezbuzz.stackato.com
