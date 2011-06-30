# Prezbuzz: a Rails 3.0 application for Stackato to track activity in the 
# current US election

## To run

# stackato push prezbuzz

# Bind a Mysql service

# ruby script/driver -h <hostname> init

# Now manually set the database to UTF-8:

# mysql `stackato service-conn prezbuzz`

> ALTER TABLE tweets CONVERT TO CHARACTER SET utf8 collate utf8_unicode_ci; 
> quit

# ruby script/driver -h <hostname> -v update

The "-v" is to make it chatty.

