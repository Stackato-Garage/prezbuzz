# From http://support.cloudfoundry.com/entries/20160007-anyway-to-run-rake-db-seed-for-rails-app

begin
if Candidate.count == 0
  load "#{RAILS_ROOT}/Rakefile"
  Rake::Task['db:seed'].invoke
else
  # $stderr.puts("**** don't launch db:seed")
end
rescue
 $stderr.puts("data_loader.rb failed: #{$!}")
end
