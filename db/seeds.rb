# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Mayor.create(:name => 'Daley', :city => cities.first)

class DataInitializer
  
  Candidates =  [["Barack<br>Obama",  "3366CC"],
       ["Michele<br>Bachmann", "DC3912"], # F02288 is too pinkish
       ["Herman<br>Cain", "FF9900"],
       ["Newt<br>Gingrich", "109618"],
       ["Jon<br>Huntsman", "990099"],
       ["Gary<br>Johnson", "0099C6"],
       ["Sarah<br>Palin", "FF2288"],
       ["Ron<br>Paul", "66AA00"],
       ["Tim<br>Pawlenty", "B82E2E"],
       ["Mitt<br>Romney", "316395"],
       ["Rick<br>Santorum", "775500"],
       ["Rick<br>Perry", "22AA99"],
       ["Chris<br>Christie", "FFEE11"],
       ["Paul<br>Ryan", "CCFF33"],
       ]
  
  def initApp
    if Meta.count == 0
      Meta.create(:processTime => (Time.now - 6.hours).utc)
      self.reload
      #self.loadSentimentWords
      self.stopWords
    else
      #$stderr.puts("Database isn't empty")
    end
    if Tweet.count == 0
      Rake::Task["harvest:update"].invoke(true)
    end
  end
  
  def reload
    Candidates.each do |line, color|
      fname, lname = line.split("<br>")
      Candidate.create({:firstName => fname, :lastName => lname, :color => color})
    end
  end
  
  def stopWords
    File.open(File.expand_path("../../app/controllers/stopWords.txt", __FILE__), "r") do |fd|
      fd.readlines.map{|s|s.chomp}.each { |wd| StopWord.create(:word => wd) }
    end
  end
  
  def loadSentimentWords
    [["../../../db/sentiment/positive-words.txt", PositiveWord],
     ["../../../db/sentiment/negative-words.txt", NegativeWord]].each do |relPath, cls|
      File.open(File.expand_path(relPath, __FILE__), "r") do |fd|
        fd.readlines.each do |wd|
          if wd[0] == ';'
            next
          end
          cls.create(:word => wd.chomp)
        end
      end
    end
  end
end

di = DataInitializer.new
di.initApp
