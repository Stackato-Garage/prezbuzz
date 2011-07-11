class StylesheetsController < ApplicationController
  layout  nil
  #session :off
  def rcss
    if rcss = params[:rcss]
      file_base = rcss.gsub(/\.css$/i, '')
      file_path = "#{Rails::root}/app/views/stylesheets/#{file_base}.rcss"
      #@candidateLastNameColors = Candidate.connection.select_rows("SELECT lastName, "#"||color from candidates")
      @candidateLastNameColors = Candidate.find(:all).map{|candidate| [candidate.lastName, "##{candidate.color}"]}
      render(:file => file_path, :content_type => "text/css")
    else
      render(:nothing => true, :status => 404)
    end
  end

end
