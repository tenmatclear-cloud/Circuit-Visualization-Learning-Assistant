FROM ruby:3.3-slim

WORKDIR /app

COPY Gemfile ./
RUN bundle config set without 'development test' \
  && bundle install

COPY . .

ENV PORT=10000
ENV HOST=0.0.0.0

EXPOSE 10000

CMD ["ruby", "server.rb"]
