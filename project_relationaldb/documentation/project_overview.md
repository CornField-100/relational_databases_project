# IMDb Clone Project - Complete Documentation

## Project Overview
This project implements a complete IMDb clone with database structure, web application queries, and comprehensive data analysis based on the IMDb non-commercial dataset.

## Part 1: Database Structure ✅

Your database schema is well-designed with the following key tables:

### Core Tables
- **titles**: Main table for movies, TV series, and episodes
- **people**: Actors, directors, writers, and other crew members  
- **title_people**: Many-to-many relationship between titles and people
- **genres**: Genre master list
- **title_genres**: Many-to-many relationship between titles and genres
- **ratings**: IMDb ratings and vote counts
- **episodes**: Links episodes to their parent TV series
- **title_details**: Extended metadata for titles

### Key Design Decisions
- Uses TEXT primary keys matching IMDb's tconst/nconst format
- Proper foreign key relationships and referential integrity
- Performance indexes on frequently queried columns
- Handles NULL values appropriately
- Supports both movies and TV content seamlessly

## Part 2: Web Application Queries

### 1. Movie Summary Page
**Purpose**: Display essential movie information for quick overview
**Query Features**:
- Aggregates directors and writers using STRING_AGG
- Shows top-rated information with ratings
- Includes genre information
- Separate query for main cast (top 5 actors)

**Performance Notes**: Uses LEFT JOINs to handle movies without ratings/cast gracefully

### 2. Movie Details Page  
**Purpose**: Show comprehensive movie information including production details
**Query Features**:
- Retrieves extended metadata from title_details table
- Shows alternative titles, languages, countries
- Includes production company information

### 3. Complete Cast/Crew Page
**Purpose**: Full cast and crew listing organized by role
**Query Features**:
- Orders by role importance (directors first, then writers, etc.)
- Shows job titles and character names
- Includes birth/death years for context

### 4. TV Series Summary Page
**Purpose**: Overview of TV series with season/episode counts
**Query Features**:
- Aggregates season and episode counts using episodes table
- Shows series duration (start/end years)
- Includes main cast information

### 5. TV Series Details Page
**Purpose**: Season-by-season breakdown with statistics
**Query Features**:
- Groups episodes by season number
- Calculates average ratings per season
- Shows total votes and episode counts per season

### 6. Episode Page
**Purpose**: Individual episode information with guest stars
**Query Features**:
- Links episode to parent series
- Shows season/episode numbers
- Includes episode-specific cast information

### 7. Person Page
**Purpose**: Complete filmography for actors/directors/writers
**Query Features**:
- Shows person's biographical information
- Complete filmography ordered by role type and year
- Includes ratings for career analysis

### 8. Movie Listing Page (with Filters)
**Purpose**: Browseable movie catalog with advanced filtering
**Query Features**:
- Dynamic filtering by genre, year, rating, adult content
- Flexible sorting options (rating, year, title, popularity)
- Pagination support with LIMIT/OFFSET
- Uses EXISTS for efficient genre filtering

**Advanced Features**:
- Adult content filtering
- Minimum rating thresholds
- Multiple sort options
- Handles NULL values gracefully

### 9. TV Series Listing Page
**Purpose**: Similar to movie listing but with TV-specific filters
**Query Features**:
- All movie filters plus TV-specific options
- Season count filtering
- End year filtering for completed series
- Aggregates season counts per series

### 10. Home Page - Featured Content
**Purpose**: Showcase top-rated movies and series
**Query Features**:
- Separate queries for movies and TV series
- Minimum vote thresholds to ensure quality
- Adult content filtering support
- Orders by rating and popularity

### Advanced Features

#### Search Engine
**Purpose**: Full-text search across titles and people
**Query Features**:
- UNION query combining title and person searches
- Case-insensitive search using ILIKE
- Result type identification
- Relevance-based ordering

#### Filter Support Queries
- Genre dropdown population
- Year range calculation for sliders
- Dynamic filter value generation

## Part 3: Data Analysis Queries

### 1. Rating Trends Analysis

#### By Decade
**Purpose**: Analyze how movie/TV ratings have evolved over time
**Advanced SQL Features**:
- Window functions with LAG() for trend calculation
- FLOOR() for decade grouping
- PERCENTILE_CONT() for median calculations
- CTE (Common Table Expression) for complex logic

**Methodology**: Groups titles by decade and calculates comprehensive statistics including rating changes between decades.

#### By Genre Over Time  
**Purpose**: Track genre performance across decades
**Advanced SQL Features**:
- Multiple GROUP BY dimensions
- HAVING clause for data quality filtering
- STDDEV() for consistency measurement

### 2. Performance Analysis

#### Directors' Career Analysis
**Purpose**: Comprehensive director performance evaluation
**Advanced SQL Features**:
- REGR_SLOPE() for career trajectory analysis
- Multiple window functions for ranking
- Complex aggregations with career span calculation
- ROW_NUMBER() for multiple ranking systems

**Insights Generated**:
- Career progression trends
- Rating consistency metrics
- Productivity vs quality analysis
- Career longevity patterns

#### Actor Success and Genre Specialization
**Purpose**: Analyze actors' career success and genre preferences
**Advanced SQL Features**:
- LATERAL joins for complex subqueries
- Multiple CTEs for step-by-step analysis
- Genre specialization identification

### 3. Relationship Analysis

#### Collaboration Networks
**Purpose**: Identify frequent director-actor partnerships
**Advanced SQL Features**:
- Self-joins on title_people table
- ARRAY_AGG() for movie list compilation
- Complex filtering for meaningful collaborations

#### Genre Combination Analysis  
**Purpose**: Find successful genre pairings
**Advanced SQL Features**:
- Self-join on title_genres with inequality condition
- Success ranking with multiple metrics
- Statistical significance filtering

#### Success Pattern Analysis
**Purpose**: Identify characteristics of highly-rated movies
**Advanced SQL Features**:
- NTILE() for quartile analysis
- Complex aggregations across multiple dimensions
- Statistical profiling of successful content

### 4. Custom Analysis: TV Series Longevity

**Purpose**: Understand factors contributing to long-running successful series
**Methodology**:
- Categories series by longevity and quality
- Analyzes patterns in episode structure
- Correlates longevity with quality metrics

**Advanced SQL Features**:
- Complex CASE statements for categorization
- Duration calculations with NULL handling
- Multi-dimensional grouping analysis

### 5. Advanced Window Functions Analysis

#### Career Trajectory Tracking
**Purpose**: Detailed individual career progression analysis
**Advanced SQL Features**:
- Running averages with ROWS BETWEEN
- Multiple window functions in single query
- Complex partitioning strategies
- LATERAL joins for dynamic calculations

### 6. Complex Aggregation with HAVING

#### Genre Performance Analysis
**Purpose**: Identify consistently high-performing genres
**Advanced SQL Features**:
- PERCENTILE_CONT() for quartile calculations
- Multiple HAVING conditions for quality filtering
- Statistical measures (STDDEV, etc.)
- Complex conditional aggregations

### 7. Performance Optimization

#### High-Popularity Content Analysis
**Purpose**: Analyze most-voted content with optimal performance
**Features**:
- RANK() window function for popularity ranking
- Optimized for large datasets
- Proper index utilization

## Performance Considerations

### Indexing Strategy
```sql
-- Key indexes for performance
CREATE INDEX idx_title_type ON titles(title_type);
CREATE INDEX idx_primary_title ON titles(primary_title);  
CREATE INDEX idx_person_name ON people(name);
CREATE INDEX idx_rating_avg ON ratings(average_rating);
```

### Query Optimization Techniques
1. **LEFT JOINs** for optional relationships
2. **EXISTS** instead of IN for subqueries
3. **Window functions** instead of self-joins where possible
4. **CTEs** for complex logic readability
5. **Proper filtering** in WHERE clauses before JOINs

### Parameterized Queries
All web application queries use parameterized inputs ($1, $2, etc.) to:
- Prevent SQL injection
- Enable query plan caching
- Improve performance

## Data Quality Considerations

### NULL Handling
- Extensive use of COALESCE() and NULLIF()
- NULL-safe comparisons in all queries
- Graceful degradation when data is missing

### Data Validation
- Minimum vote thresholds for meaningful ratings
- Year range filtering for data quality
- Existence checks before foreign key operations

## Advanced SQL Features Demonstrated

1. **Window Functions**: LAG, LEAD, ROW_NUMBER, RANK, NTILE, running averages
2. **Aggregate Functions**: STRING_AGG, ARRAY_AGG, statistical functions
3. **CTEs**: Complex multi-step analysis
4. **LATERAL Joins**: Dynamic subqueries
5. **Set Operations**: UNION for search functionality
6. **Statistical Functions**: REGR_SLOPE, PERCENTILE_CONT, STDDEV
7. **Array Operations**: String parsing and array aggregation
8. **Complex Grouping**: GROUPING SETS, multiple dimensions

## Project Structure Recommendation

```
project_relationaldb/
├── README.md (this file)
├── schema/
│   ├── schema.sql (your existing schema)
│   └── init.sql (your Docker init)
├── import/
│   └── import_all.sql (your existing import)
├── queries/
│   ├── web_queries.sql (Part 2 queries)
│   └── analysis_queries.sql (Part 3 queries)
├── documentation/
│   └── queries_explanation.md (this documentation)
├── docker/
│   └── docker-compose.yml (your existing Docker setup)
└── analysis/
    └── sample_results.md (example query outputs)
```

## How to Use These Queries

### For Web Application Development
1. Use the web queries as templates for your application endpoints
2. Replace parameter placeholders ($1, $2, etc.) with actual values
3. Implement pagination for listing queries
4. Add appropriate error handling

### For Data Analysis
1. Run analysis queries against your populated database
2. Export results to CSV for visualization tools
3. Use results to generate charts and graphs
4. Document insights and patterns discovered

## Next Steps for Completion

1. **Test all queries** against your imported data
2. **Generate sample outputs** for each analysis query
3. **Create visualizations** from analysis results
4. **Document performance metrics** for each query type
5. **Add additional indexes** if needed based on query performance

This completes your IMDb clone project with sophisticated database design, comprehensive web application support, and advanced data analysis capabilities.