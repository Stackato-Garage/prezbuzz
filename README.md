# Prezbuzz

Prezbuzz is a Rails 3.0 application that tracks the twitter activity
related to the candidates running for the American 2012 Presidential Election

See LICENSE.txt for the license on PrezBuzz

To get Prezbuzz working, it needs to be deployed, initialized, and
then updated on a regular basis.

## Prerequisities:

You'll need Ruby (1.8.7 or 1.9.2) and Rails 3.0 installed.  We recommend
installing a Ruby sandbox using rvm

    ($ bash < <(curl -s https://rvm.beginrescueend.com/install/rvm))
    
This command might fail due to certificate issues.  If so, try adding the -k
flag to curl, or downloading the script separately, and handing it to bash locally.
    
    . ~/.bashrc   # Add rvm to your path
    
    rvm install 1.9.2 
    rvm list
    rvm use 1.9.2  # Or whichever is closest to the 1.9.2 you installed
    gem install rails --version=3.0.0
    
or find out more at <https://rvm.beginrescueend.com/>.

Now go to the directory that contains this file, and pull down
any other required gems:

    bundle install
    
## To run the app locally:

The app is configured to run with mysql.  To run with sqlite3
locally (during testing), change the development section in
config/database.yml to the following (assuming that you have
sqlite3 and the ruby adapter installed on your system):

    adapter: sqlite3
    database: dv/development.sqlite3
    pool: 5
    timeout: 5000
    
Initialize the database:

    rake db:migrate
    
Start the server:

    rails server webrick
    
Change to another console, in the same directory, with
the same environment, and initialize the database:

    ruby script/driver.rb -h localhost -p 3000 init
    
Now populate the database:

    ruby script/driver.rb -h localhost -p 3000 update -v
    
If it's slow, keep in mind that sqlite3 is a few orders of
magnitude slower than a networked database.

## To deploy:

   stackato push prezbuzz

       Bind a Mysql service

## To initialize:

    ruby script/driver -h <hostname> init
    # Now manually set the database to UTF-8:
    mysql `stackato service-conn prezbuzz`
    > ALTER TABLE tweets CONVERT TO CHARACTER SET utf8 collate utf8_unicode_ci;
    > quit

## To update:

    ruby script/driver -h <hostname> update

This is best run as part of a cron job once every hour or two.


## Test the app in a browser:

<http://prezbuzz.stackato.activestate.com/>

