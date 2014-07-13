#!/usr/local/bin/ruby -rubygems

require 'sinatra'
require 'rethinkdb'
require './foldl'

RDB_CONFIG = {
  :host => ENV['RDB_HOST'] || 'localhost', 
  :port => ENV['RDB_PORT'] || 28015,
  :db   => ENV['RDB_DB']   || 'research'
}

# A friendly shortcut for accessing ReQL functions
r = RethinkDB::RQL.new

#### Setting up the database

configure do
  set :db, RDB_CONFIG[:db]
  begin
    connection = r.connect(
      :host => RDB_CONFIG[:host],
      :port => RDB_CONFIG[:port])
  rescue Exception => err
    puts "Cannot connect to RethinkDB database #{RDB_CONFIG[:host]}:#{RDB_CONFIG[:port]} (#{err.message})"
    Process.exit(1)
  end

  begin
    r.db_create(RDB_CONFIG[:db]).run(connection)
  rescue RethinkDB::RqlRuntimeError => err
    puts "Database `research` already exists."
  end

  begin
    r.db(RDB_CONFIG[:db]).table_create('books').run(connection)
  rescue RethinkDB::RqlRuntimeError => err
    puts "Table `books` already exists."
  ensure
    connection.close
  end
end

before do
  begin
    # When opening a connection we can also specify the database:
    @rdb_connection = r.connect(
      :host => RDB_CONFIG[:host],
      :port => RDB_CONFIG[:port],
      :db => settings.db)
  rescue Exception => err
    logger.error "Cannot connect to RethinkDB database #{RDB_CONFIG[:host]}:#{RDB_CONFIG[:port]} (#{err.message})"
    halt 501, 'This page could look nicer, unfortunately the error is the same: database not available.'
  end
end

after do
  begin
    @rdb_connection.close if @rdb_connection
  rescue
    logger.warn "Couldn't close connection"
  end
end

get '/' do
  "This is the WordTree library API"
end

def match_list(params, string_keys=[], numeric_keys=[], escape=true)
  Proc.new do |record|
    (
      string_keys.map do |key|
        if params[key]
          term = escape ? Regexp.escape(params[key]) : params[key]
          record[key.to_s].match("(?i)#{term}")
        end
      end +
      numeric_keys.map do |key|
        if params[key]
          if params[key].include?(',')
            low, high = params[key].split(',', 2).map{ |v| v.to_i }
            (record[key.to_s] >= low) & (record[key.to_s] <= high)
          else
            value = params[key].to_i
            record[key.to_s].eq(value)
          end
        end
      end
    ).compact.foldl{ |a,b| a & b }
  end
end

get '/book/:id' do
  content_type :json
  errors = []
  books = []
  if result = r.table('books').get(params[:id]).run(@rdb_connection)
    books << result
  else
    errors << "Book id '#{params[:id]}' not found"
  end
  
  JSON.pretty_generate({"errors" => errors, "books" => books})
end

get '/search' do
  content_type :json
  errors = []
  books = []
  conditions = match_list(params, [:file_id, :title, :author, :source, :status], [:year, :size_bytes])
  cursor = r.table('books').order_by(:index => 'year').filter(&conditions).limit(20).run(@rdb_connection)
  results = cursor.to_a
  if !results.empty?
    books = results
  else
    errors << "No books found that match the search criteria"
  end

  JSON.pretty_generate({"errors" => errors, "books" => books})
end
