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

- Forp Getting TOP 10 rated shows which are releasing new episodes on a given date:
    -- SampleURL: http://localhost:3000/episodes?q[airdate_eq]=2025-05-22&q[show_avg_rating_not_null]=1&q[s]=show_avg_rating+desc&page=1&per_page=10
    -- See how the Pagination and filteration and inner nested show_avg_rating is used for sorting and filteration of non null values
