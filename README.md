# WordTree Library API

This is the Library API server for WordTree. It provides access to books in the
WordTree library.

NOTE: This is not a client library (in the software sense). This is the server
portion that we host on our end, so you probably don't need it.

## Prerequisites

You should have a RethinkDB server and a chaNginx server running.

  - https://github.com/wordtreefoundation/dockerfiles/tree/master/rethinkdb
  - https://github.com/wordtreefoundation/dockerfiles/tree/master/changinx

## Deployment

    docker run -d --name api-library \
               --link changinx:nx \
               -e "RDB_HOST=[RethinkDB Host IP]" \
               wordtree/api-library

For instance, I have RethinkDB running on 192.168.1.149, so I would use:

    -e "RDB_HOST=192.168.1.149"

## Usage

This is likely to change frequently, but at the time of writing, you can access
these API endpoints:

- Access a single book, by file_id: http://docker/library/book/firstbooknapole00gruagoog
- Search for books published between 1827 and 1830: http://files.wordtree.org/library/search?year=1827,1830
- Search for books with "bible" in the title: http://files.wordtree.org/library/search?title=bible

