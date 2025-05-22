# README

This README encapsulates the local setup of running the rails api application in local without the container (docker).

# Requirements

## Ruby version - 3.2.2

## PostgresQL and Redis
PostgresQL of 14+ is advised (15 preferred). Redis is needed to run the jobs via sidekiq.
To install postgresql@14 and redis utilize brew in mac or linux environments
``` brew install postgreql@14 ```
``` brew install redis ```
* Note: Ensure the ports used by postgreql and redis are not used by other programs in your local machine


## Gem File setup
To setup and install required gems 
``` gem install bundler```
and then utilize ```bundle install```
## Database creation & initialization

To create the database utilize the commands - ``` rails db:create ```
To Migrate the database schema changes use - ```rails db:migrate```

## How to run the test suite

``` bundle exec rspec```

Note: Ensure the rails db:migrate is executed eariler to ensure test database is also created parallely

## Services (job queues, cache servers, search engines, etc.)

To start sidekiq (background jobs processing)
``` bundle exec sidekiq ```

## Deployment instructions

``` rails s ``` to locally start the server
