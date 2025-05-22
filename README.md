# looperinsights-assignment
A Ruby Application to scrap upcoming tv shows data for the next 90 days with good coding practices.


# Database Setup (Local Docker)
- Ensure docker-compose command is installed and working.
- utilise the command ``` docker-compose -f docker-compose-local.yml up -d ```

# Docker Local Services
- Database (PostgreQL15)
- Redis (needed for sidekiq)
- Rails API server 
- Sidekiq Server (To run background jobs via cron scheduler automatically)

# Sample REST Endpoints with Ransack for Aggegration and Filteration

- For Getting TOP 10 rated shows which are releasing new episodes on a given date:
    SampleURL: ``` http://localhost:3000/episodes?q[airdate_eq]=2025-05-22&q[show_avg_rating_not_null]=1&q[s]=show_avg_rating+desc&page=1&per_page=10 ```
    
    Notes: Pagination and filteration and inner nested show_avg_rating is used for sorting and filteration of non null values. The pagination is used to achieve the TOP 10 filteration when paired with sorting.
- For Getting a particular title with a word "After"
    SampleURL: ``` http://localhost:3000/episodes?q[name_cont]=After&page=1&per_page=10 ```
    Notes: q[attributename_cont] means contains and leads to filteration of results (searching). This can be utilised also in Nested attributes which we will see a soon.

- For Searching Shows from a Particular Network such as CBS
    SampleURL: ``` http://localhost:3000/shows/query?q[network_name]=CBS ```
    Notes: Nested Attributes are also enabled in search hence it does automatic look up of necessary tables and filters the results
- For Searching or multi matching genres, to find all shows which has genre Comedy,Music
    SampleURL: ```http://localhost:3000/shows/query?q[genres_array_contains_all]=Comedy,Music```
    Notes: For Array serach we have added scope, if the attribute is a special such as jsonb or array then scopes are added to facilitate smooth searching.
- For Searching genres along with chained queries in name matching
    SampleURL: ```http://localhost:3000/shows/query?q[genres_array_contains_all]=Comedy,Music&q[name_cont]=After```
    Notes: Any number of chaining of attributes or nested attributes along with sorting is possible. The Pagination also is customizable and has default values when not provided.

- For more documentation of ransack and its abilities visit [ransack-documentation](https://activerecord-hackery.github.io/ransack/)