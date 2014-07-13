FROM dockerfile/ruby

ADD app /app
ADD run.sh /app/run.sh

WORKDIR /app

RUN bundle install

EXPOSE 8080

ENV APP_PORT 8080
ENV APP_NAME library
ENV APP_MOUNT /library

CMD ./run.sh
