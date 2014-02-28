class MainController < ApplicationController
  include TopicsHelper
  include MapsHelper
  include UsersHelper
  include SynapsesHelper

  before_filter :require_user, only: [:invite, :newtopic] 
   
  respond_to :html, :js, :json
  
  # home page
  def home
    if authenticated? && is_mobile_device?
      redirect_to "/maps/mappers/" + user.id.to_s
    else 
      @maps = Map.order("updated_at DESC").limit(3)
    
      respond_with(@maps)
    end
  end
  
  # /newtopic this one is for mobile
  def newtopic
    @current = current_user
    @maps = Map.all
    
    # in require_user above we confirm that they're logged in, now we just have to limit the map results to their own maps, and commons maps
    @maps.delete_if {|m| (m.permission == "private" || m.permission == "public") && @current.id != m.user_id }
    respond_with(@maps)
  end
  
  ### SEARCHING ###
  
  # get /search/topics?term=SOMETERM
  def searchtopics
    @current = current_user
    
    term = params[:term]
    user = params[:user] ? params[:user] : false
    
    if term && !term.empty? && term.downcase[0..3] != "map:" && term.downcase[0..6] != "mapper:" && term.downcase != "topic:"
      
      #remove "topic:" if appended at beginning
      term = term[6..-1] if term.downcase[0..5] == "topic:"
      
      #if desc: search desc instead
      desc = false
      if term.downcase[0..4] == "desc:"
        term = term[5..-1] 
        desc = true
      end
      
      #if link: search link instead
      link = false
      if term.downcase[0..4] == "link:"
        term = term[5..-1] 
        link = true
      end
      
      #check whether there's a filter by metacode as part of the query
      filterByMetacode = false
      Metacode.all.each do |m|
        lOne = m.name.length+1
        lTwo = m.name.length
        
        if term.downcase[0..lTwo] == m.name.downcase + ":"
          term = term[lOne..-1] 
          filterByMetacode = m
        end
      end
      
      if filterByMetacode
        if term == ""
          @topics = []
        else
          search = term.downcase + '%'
          
          if !user
            @topics = Topic.where('LOWER("name") like ?', search).where('metacode_id = ?',  filterByMetacode.id).order('"name"')
            @topics2 = Topic.where('LOWER("name") like ?', '%' + search).where('metacode_id = ?',  filterByMetacode.id).order('"name"')
            @topics3 = Topic.where('LOWER("desc") like ?', '%' + search).where('metacode_id = ?',  filterByMetacode.id).order('"name"')
            @topics4 = Topic.where('LOWER("link") like ?', '%' + search).where('metacode_id = ?',  filterByMetacode.id).order('"name"')
            @topics = @topics + (@topics2 - @topics)
            @topics = @topics + (@topics3 - @topics)
            @topics = @topics + (@topics4 - @topics)
            
          elsif user
            @topics = Topic.where('LOWER("name") like ?', search).where('metacode_id = ? AND user_id = ?',  filterByMetacode.id, user).order('"name"')
            @topics2 = Topic.where('LOWER("name") like ?', '%' + search).where('metacode_id = ? AND user_id = ?',  filterByMetacode.id, user).order('"name"')
            @topics3 = Topic.where('LOWER("desc") like ?', '%' + search).where('metacode_id = ? AND user_id = ?',  filterByMetacode.id, user).order('"name"')
            @topics4 = Topic.where('LOWER("link") like ?', '%' + search).where('metacode_id = ? AND user_id = ?',  filterByMetacode.id, user).order('"name"')
            @topics = @topics + (@topics2 - @topics)
            @topics = @topics + (@topics3 - @topics)
            @topics = @topics + (@topics4 - @topics)
            
          end
        end
      elsif desc
        search = '%' + term.downcase + '%'
        if !user
          @topics = Topic.where('LOWER("desc") like ?', search).order('"name"')
        elsif user
          @topics = Topic.where('LOWER("desc") like ?', search).where('user_id = ?', user).order('"name"')
        end
      elsif link
        search = '%' + term.downcase + '%'
        if !user
          @topics = Topic.where('LOWER("link") like ?', search).order('"name"')
        elsif user
          @topics = Topic.where('LOWER("link") like ?', search).where('user_id = ?', user).order('"name"')
        end
      else #regular case, just search the name
        search = term.downcase + '%'
        if !user
          @topics = Topic.where('LOWER("name") like ?', search).order('"name"')
          @topics2 = Topic.where('LOWER("name") like ?', '%' + search).order('"name"')
          @topics3 = Topic.where('LOWER("desc") like ?', '%' + search).order('"name"')
          @topics4 = Topic.where('LOWER("link") like ?', '%' + search).order('"name"')
          @topics = @topics + (@topics2 - @topics)
          @topics = @topics + (@topics3 - @topics)
          @topics = @topics + (@topics4 - @topics)
        elsif user
          @topics = Topic.where('LOWER("name") like ?', search).where('user_id = ?', user).order('"name"')
          @topics2 = Topic.where('LOWER("name") like ?', '%' + search).where('user_id = ?', user).order('"name"')
          @topics3 = Topic.where('LOWER("desc") like ?', '%' + search).where('user_id = ?', user).order('"name"')
          @topics4 = Topic.where('LOWER("link") like ?', '%' + search).where('user_id = ?', user).order('"name"')
          @topics = @topics + (@topics2 - @topics)
          @topics = @topics + (@topics3 - @topics)
          @topics = @topics + (@topics4 - @topics)
        end
      end
    else
      @topics = []
    end
    
    #read this next line as 'delete a topic if its private and you're either 1. logged out or 2. logged in but not the topic creator
    @topics.delete_if {|t| t.permission == "private" && (!authenticated? || (authenticated? && @current.id != t.user_id)) }
    
    render json: autocomplete_array_json(@topics)
  end
  
  # get /search/maps?term=SOMETERM
  def searchmaps
    @current = current_user
    
    term = params[:term]
    user = params[:user] ? params[:user] : nil
    
    if term && !term.empty? && term.downcase[0..5] != "topic:" && term.downcase[0..6] != "mapper:" && term.downcase != "map:"
    
      #remove "map:" if appended at beginning
      term = term[4..-1] if term.downcase[0..3] == "map:"
      
      #if desc: search desc instead
      desc = false
      if term.downcase[0..4] == "desc:"
        term = term[5..-1] 
        desc = true
      end
      search = '%' + term.downcase + '%'
      query = desc ?  'LOWER("desc") like ?' : 'LOWER("name") like ?'
      if !user
      	# !connor why is the limit 5 done here and not above? also, why not limit after sorting alphabetically?
        @maps = Map.where(query, search).limit(5).order('"name"')
      elsif user
        @maps = Map.where(query, search).where('user_id = ?', user).limit(5).order('"name"')
      end
    else
      @maps = []
    end
    
    #read this next line as 'delete a map if its private and you're either 1. logged out or 2. logged in but not the map creator
    @maps.delete_if {|m| m.permission == "private" && (!authenticated? || (authenticated? && @current.id != m.user_id)) }
    
    render json: autocomplete_map_array_json(@maps)
  end
  
  # get /search/mappers?term=SOMETERM
  def searchmappers
    @current = current_user
    
    term = params[:term]
    if term && !term.empty?  && term.downcase[0..3] != "map:" && term.downcase[0..5] != "topic:" && term.downcase != "mapper:"
    
      #remove "mapper:" if appended at beginning
      term = term[7..-1] if term.downcase[0..6] == "mapper:"
      @mappers = User.where('LOWER("name") like ?', term.downcase + '%').limit(5).order('"name"')
    else
      @mappers = []
    end
    render json: autocomplete_user_array_json(@mappers)
  end 
  
  # get /search/synapses?term=SOMETERM OR
  # get /search/synapses?topic1id=SOMEID&topic2id=SOMEID
  def searchsynapses
    @current = current_user
    
    term = params[:term]
    topic1id = params[:topic1id]
    topic2id = params[:topic2id]
    
    if term && !term.empty?
      @synapses = Synapse.select('DISTINCT "desc"').
        where('LOWER("desc") like ?', '%' + term.downcase + '%').limit(5).order('"desc"')
      
      render json: autocomplete_synapse_generic_json(@synapses)
      
    elsif topic1id && !topic1id.empty?
      @one = Synapse.where('node1_id = ? AND node2_id = ?', topic1id, topic2id)
      @two = Synapse.where('node2_id = ? AND node1_id = ?', topic1id, topic2id)
      @synapses = @one + @two
      @synapses.sort! {|s1,s2| s1.desc <=> s2.desc }
      
      #read this next line as 'delete a synapse if its private and you're either 1. logged out or 2. logged in but not the synapse creator
      @synapses.delete_if {|s| s.permission == "private" && (!authenticated? || (authenticated? && @current.id != s.user_id)) }
    
      render json: autocomplete_synapse_array_json(@synapses)
    else
      @synapses = []
      render json: autocomplete_synapse_array_json(@synapses)
    end
  end 

end
