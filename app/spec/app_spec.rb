require_relative './spec_helper'
require_relative '../app'
require 'fileutils'

describe "API Library" do
  def app
    Sinatra::Application
  end

  describe "GET /" do
    it "lists links" do
      get "/"
      expect(JSON.parse(last_response.body)["links"].size).to be >= 1
    end
  end

  describe "GET /book/:id" do
    it "returns a book if found" do
      db_init
      r.table('books').insert(:id => "book", :year => 1800).run(rdb)

      get "/book/book"
      expect(last_response).to be_ok
      expect(JSON.parse(last_response.body)["books"]).to \
        eq([{"id"=>"book", "year"=>1800}])
    end

    it "returns an error if book not found" do
      get "/book/nobook"
      expect(last_response).to be_ok
      expect(JSON.parse(last_response.body)["errors"]).to \
        eq(["Book id 'nobook' not found."])
    end
  end

  describe "PUT /book/:id" do
    it "creates a book in the db" do
      db_init

      put "/book/test", :id => "test", :year => 1800
      result = r.table('books').get("test").run(rdb)
      expect(result).to eq("id" => "test", "year" => 1800)
      expect(JSON.parse(last_response.body)["errors"]).to eq([])
    end

    it "creates a book on disk" do
      path = File.join(ENV['LIBRARY'], "te", "st", "test", "test.md")
      FileUtils.rm_f(path)
      expect(File.exist?(path)).to_not be_true
      put "/book/test", :id => "test", :year => 1800
      expect(File.exist?(path)).to be_true
    end
  end

  describe "GET /book/:id/content" do
    it "returns an error if not found" do
      get '/book/nobook/content'
      expect(last_response).to_not be_ok
      expect(last_response.body).to \
        eq("Book 'nobook' not found on disk\n")
    end

    context "with fixture library" do
      before(:all) do
        @previous_library_value = CONFIG[:library]
        CONFIG[:library] = fixture('library')
      end

      after(:all) do
        CONFIG[:library] = @previous_library_value
      end

      it "returns clean book content when 'clean=1'" do
        get '/book/book/content', "clean" => "1"
        expect(last_response).to be_ok
        expect(last_response.body).to \
          eq("book with content\n")
      end

      it "returns book content" do
        get '/book/book/content'
        expect(last_response).to be_ok
        expect(last_response.body).to \
          eq("Book with content")
      end
    end
  end

  describe "GET /search" do
    context "with books in db" do
      before do
        db_init
        books = (1700..1900).map{ |y| {:id => "book#{y}", :year => y} }
        r.table('books').insert(books).run(rdb)
      end

      it "returns a book if found" do
        get "/search", "year" => "1800,1801"
        expect(last_response).to be_ok
        expect(JSON.parse(last_response.body)["books"]).to \
          eq([{"id" => "book1800", "year" => 1800},
              {"id" => "book1801", "year" => 1801}])
      end

      it "returns paginated results" do
        get "/search", "year" => "1800,1810", "per_page" => "2", "page" => "2"
        expect(last_response).to be_ok
        expect(JSON.parse(last_response.body)["books"]).to \
          eq([{"id" => "book1802", "year" => 1802},
              {"id" => "book1803", "year" => 1803}])
      end

      it "returns an error if no books found" do
        get "/search", "year" => "1500,1600"
        expect(last_response).to be_ok
        expect(JSON.parse(last_response.body)["books"]).to eq([])
        expect(JSON.parse(last_response.body)["errors"]).to \
          eq(["No books found that match the search criteria"])
      end
    end
  end
end