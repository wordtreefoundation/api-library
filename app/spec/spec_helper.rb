require 'rspec'
require 'rack/test'
require 'tmpdir'

module Fixtures
  def fixture(name)
    File.join(File.dirname(__FILE__), 'fixtures', name)
  end
end

module RethinkMethods
  def r
    RethinkDB::RQL.new
  end

  def rdb
    r.connect(
      :host => ENV["RDB_HOST"],
      :port => ENV["RDB_PORT"],
      :db   => ENV["RDB_DB"]
    )
  end

  def librarian
    WordTree::DB::Librarian.new(rdb)
  end

  def db_init
    begin
      r.table_drop('books').run(rdb)
    rescue RethinkDB::RqlRuntimeError
    ensure
      r.table_create('books').run(rdb)
    end

    begin
      r.table('books').index_drop('year').run(rdb)
    rescue RethinkDB::RqlRuntimeError
    ensure
      r.table('books').index_create('year').run(rdb)
    end
  end
end

ENV['RACK_ENV'] = 'test'

ENV['RDB_HOST'] = 'localhost'
ENV['RDB_PORT'] = '28015'
ENV['RDB_DB'] = 'test'
ENV['LIBRARY'] = Dir.mktmpdir

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include Fixtures
  config.include RethinkMethods
end