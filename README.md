# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version  
ruby 3.2.2

* System dependencies

* Configuration  
  ```
  $ bundle install --path vendor/bundle
  $ brew install redis 
  
  $ mkdir downloads  
  $ mkdir downloads/results  
  $ mkdir downloads/tmp_results 
  ``` 
  
  配置 config/credentials/development.key, config/credentials/test.key, config/credentials/dev.key, config/master.key,  
  変更 config/credentials/development.yml.enc, config/credentials/test.yml.enc, config/credentials/dev.yml.enc
  ```
  development.yml.enc, test.yml.encの以下を変更
  virus_check:
    directory:
    log: 
  ```
  
  

* Database creation 
  ```  
  $ bundle exec rails db:create  
  $ bundle exec rails db:create RAILS_ENV=test
  
* Database initialization  
  ``` 
  $ bundle exec rails db:migrate  
  $ bundle exec rails db:seed 
  ``` 

* How to run the server  
  ``` 
  $ mysql.server start  
  $ redis-server  
  $ bundle exec sidekiq -C config/sidekiq.yml -e development
  ``` 


* Run crawler manually  
  ``` 
  $ bundle exec rails console
  
  Tasks::WorkersHandler.execute
  
  # Access to check crawling
  http://localhost:3000/sidekiq/queues
  ``` 

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Design  
  Materialize(https://materializecss.com/)

* Deployment instructions

* ...

## Rspec test
* Prepare db record seeds
  ```
  bundle exec rails db:seeds_country test
  ```

* Execute rspec
  ```
  bundle exec rspec spec
  ```
  
* Execute rspec with spring for fast test
  ```
  bundle exec spring rspec spec
  
  # stop spring because hevy CPU utilization.
  bundle exec spring stop
  ```

* Parallel rspec test
  ```
  bin/my-rspec-queue spec
  ```
