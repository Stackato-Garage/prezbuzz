# Prezbuzz

Prezbuzz is a Rails 3.0 application that tracks the twitter activity
related to the candidates running for the American 2012 Presidential Election

See LICENSE.txt for the license on PrezBuzz

To get Prezbuzz working, it needs to be deployed, initialized, and
then updated on a regular basis.

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

