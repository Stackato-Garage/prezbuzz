# Prezbuzz

Prezbuzz is a Rails 3.0 application that tracks the twitter activity
related to the candidates running for the American 2012 Presidential Election.

See LICENSE.txt for the license on PrezBuzz

To get Prezbuzz working, it needs to be deployed, initialized, and
then updated on a regular basis. This README covers running it on bare
hardware (e.g. your workstation) and deploying it to Stackato. Prezbuzz
can initialize and update itself; this document will explain how.

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
    
## Deploying to Stackato:

In the top-level directory of the project, run:

    stackato push -n

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
    
### Running Unit Tests:

The first time you run the tests, you'll need to build a test database schema:

    rake db:test:prepare

Now running tests is simple:

    rake test/units # Tests the models

    rake test/functionals # Tests the tweets and harvester controllers
    
The data for the tests is given in the test/fixtures files, and a database,
db/test.sqlite, is built from this data each time the tests are run.  The
tests modify the database as they run, but the database is left for further
analysis after the tests finish running.  Each time the tests are run the
test database is rebuilt from the fixtures.

The easiest way to comment out a test is to rename its "test" header
to "htest".   For example, in tweet_test.rb, line 6, rename

    test "item 1" do
    
to

    htest "item 1" do

### Running the Server:

Start the server:

    rails server webrick
    
Change to another console, in the same directory, with the same
environment, and start interacting with the server.

If you've modified the list of candidates, or their colors, you'll need to
rebuild the CSS file:

    curl 'http://localhost:3000/stylesheets/rcss?rcss=candidateBuzz' > public/stylesheets/candidateBuzz.css
    
The first time the server starts up, it should start harvesting tweets and
entering them in the database.   You can run this step manually with this command:

    bundle exec rake 'harvest:update[true]'

Set the argument to "false" to turn verbose output off.

If it's slow, keep in mind that sqlite3 is a few orders of
magnitude slower than a networked database. If you don't want to see all
that output, you can specify a verbosity option of "false".

If you change the candidates' colors, or add/remove candidates, you'll
need to rebuild candidates.css, like so:

   curl 'http://localhost:3000/stylesheets/rcss?rcss=candidateBuzz' > public/stylesheets/candidateBuzz.css

This will need to be done on the server as well.

### Set database tables to use UTF-8

Change the default character set for MySQL tables to accomodate UTF-8
twitter data: 
    
    stackato dbshell
    > ALTER TABLE tweets CONVERT TO CHARACTER SET utf8 collate utf8_unicode_ci;
    > quit
 
### Populate/Update twitter data:

If this is the first time the app is being deployed, run the following
command to pull in the initial set of data:

    stackato run ruby script/batch_harvester.rb update

Prezbuzz's stackato.yml file contains two cron lines which update and maintain
the twitter data. The first line

    0 * * * * /opt/rubies/1.9.3-p125/bin/bundle exec rake 'harvest:update[false]' >> $HOME/../logs/update.log
    
loads new tweets once an hour, on the hour (we recommend changing the leading
"0" to a random value between 5 and 55 to avoid swamping the twitter API). The
second line

    30 10 29 * * /opt/rubies/1.9.3-p125/bin/bundle exec rake 'harvest:cull[false,nil]' >> $HOME/../logs/cull.log
    
removes tweets that are at least one month old at 10:30 UTC on the 29th of each
month. We have found doing this improves performance.  You can run both these
commands like so manually from the command-line, leaving off the full path to
bundle.

Running '... rake harvest:status` shows how many tweets are
currently in the database, and gives their average age.

### Test the app in a browser:

With a micro-cloud deployment of Stackato, the default URL would be:

  http://prezbuzz.stackato.local
  
A hosted version of the same app can be found here:

  http://buzz.stackato.com

## To add a new candidate

We haven't automated this step via the app UI yet.  Here's what you need to do:

1. edit `db/seeds.rb` to indicate what you want.  This data is only used when an
   app is init'ed, but it's a good marker

2. add new entries in `public/stylesheets/candidateBuzz.css` for
   `body.Smith div#buzz_candidate` and `body.Smith #buzz_details` (assuming
   we're adding John Smith here, and we have no other candidates named "Smith").
   
3. add a 128x128 PNG image for the new candidate in `public/images`.  If you're
   adding a candidate named John Smith, the image should be called `Smith.png`.
   The best place to get this is image is from the candidate's twitter profile.

4. run 

       stackato dbshell prezbuzz

   and insert the new line in the candidates table.  Here's the syntax for
   John Smith with color magenta:
   
       INSERT INTO candidates (firstName, lastName, color) VALUES
         ('John', 'Smith', 'FF00FF');
    
    The color string is case-insensitive, but prezbuzz conventionally uses upper-case.

5. run

        stackato bundle exec rake 'harvest:update[false]'


6. test the app
