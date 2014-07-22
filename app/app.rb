#!/usr/local/bin/ruby -rubygems

require 'sinatra'
require 'rethinkdb'
require 'yaml'

$:.unshift(File.join(File.dirname(__FILE__), 'lib'))

require 'foldl'
require 'wordtree'

CONFIG = {
  :host          => ENV['RDB_HOST'] || 'localhost', 
  :port          => ENV['RDB_PORT'] || 28015,
  :db            => ENV['RDB_DB']   || 'research',
  :library       => ENV['LIBRARY'] || 'library'
}

# A friendly shortcut for accessing ReQL functions
r = RethinkDB::RQL.new

#### Setting up the database

configure do
  set :db, CONFIG[:db]
  begin
    connection = r.connect(
      :host => CONFIG[:host],
      :port => CONFIG[:port])
  rescue Exception => err
    puts "Cannot connect to RethinkDB database #{CONFIG[:host]}:#{CONFIG[:port]} (#{err.message})"
    Process.exit(1)
  end

  begin
    r.db_create(CONFIG[:db]).run(connection)
  rescue RethinkDB::RqlRuntimeError => err
    puts "Database `#{CONFIG[:db]}` already exists."
  end

  begin
    r.db(CONFIG[:db]).table_create('books').run(connection)
  rescue RethinkDB::RqlRuntimeError => err
    puts "Table `books` already exists."
  ensure
    connection.close
  end
end

helpers do
  def json_books_response(&block)
    json_response do |object|
      object["books"] = (books = [])
      object["messages"] = (messages = [])
      object["errors"] = (errors = [])
      yield books, messages, errors if block_given?
    end
  end

  def json_response(&block)
    content_type :json

    object = {}
    yield object if block_given?
    
    JSON.pretty_generate(object)
  end

  def param_true?(value)
    value.to_i == 1 || value == "true"
  end
end

before do
  begin
    # When opening a connection we can also specify the database:
    @rdb_connection = r.connect(
      :host => CONFIG[:host],
      :port => CONFIG[:port],
      :db => settings.db)
  rescue Exception => err
    logger.error "Cannot connect to RethinkDB database #{CONFIG[:host]}:#{CONFIG[:port]} (#{err.message})"
    halt 501, 'This page could look nicer, unfortunately the error is the same: database not available.'
  end
  @library  = WordTree::Disk::Library.new(CONFIG[:library])
  @disk_lib = WordTree::Disk::Librarian.new(@library)
  @db_lib   = WordTree::DB::Librarian.new(@rdb_connection)
end

after do
  begin
    @rdb_connection.close if @rdb_connection
  rescue
    logger.warn "Couldn't close connection"
  end
end


get '/' do
  json_response do |object|
    object[:title] = "This is the WordTree library API"
    object[:links] = {
      "GET /book/:id" => "Get a book",
      "PUT /book/:id" => "Insert or update a book's metadata"
    }
  end
end

get '/book/:id' do
  json_books_response do |books, msgs, errs|
    if book = @db_lib.find(params[:id])
      books << book.metadata
    else
      errs << "Book id '#{params[:id]}' not found."
    end
  end
end

put '/book/:id' do
  json_books_response do |books, msgs, errs|
    book = WordTree::Book.new(params)
    unless @db_lib.save(book)
      errs << "Unable to save book to DB"
    end
    unless @disk_lib.save(book)
      errs << "Unable to save book on disk"
    end
  end
end

get '/book/:id/content' do
  content_type :text

  if book = @disk_lib.find(params[:id])
    wrap = (params[:wrap] || "120").to_i
    wrap = 30 if wrap < 30
    param_true?(params[:clean]) ? book.content_clean(wrap) : book.content
  else
    [404, "Book '#{params[:id]}' not found on disk\n"]
  end
end

get '/search' do
  json_books_response do |books, msgs, errs|
    page = (params[:page] || '1').to_i
    per_page = (params[:per_page] || '20').to_i
    found_books = @db_lib.search(params, page, per_page)
    if found_books.nil?
      errs << "No books found that match the search criteria"
    else
      found_books.each { |book| books << book.metadata }
    end
  end
end
