-- ===================================================
-- Part 3: Data Analysis & Visualization Queries
-- ===================================================

-- ===============================
-- 1. RATING TRENDS ANALYSIS
-- ===============================

-- Rating trends by decade
-- Purpose: Analyze how movie/TV ratings have changed over decades
WITH decade_ratings AS (
    SELECT 
        FLOOR(t.start_year / 10) * 10 AS decade,
        t.title_type,
        AVG(r.average_rating) AS avg_rating,
        COUNT(*) AS title_count,
        SUM(r.num_votes) AS total_votes,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY r.average_rating) AS median_rating
    FROM titles t
    JOIN ratings r ON t.id = r.title_id
    WHERE t.start_year IS NOT NULL 
        AND t.start_year >= 1920  -- Focus on modern cinema
        AND r.num_votes >= 100    -- Filter for meaningful ratings
    GROUP BY FLOOR(t.start_year / 10) * 10, t.title_type
)
SELECT 
    decade,
    title_type,
    ROUND(avg_rating, 2) AS average_rating,
    title_count,
    total_votes,
    ROUND(median_rating, 2) AS median_rating,
    -- Calculate rating trend vs previous decade
    LAG(avg_rating) OVER (PARTITION BY title_type ORDER BY decade) AS prev_decade_rating,
    ROUND(avg_rating - LAG(avg_rating) OVER (PARTITION BY title_type ORDER BY decade), 2) AS rating_change
FROM decade_ratings
ORDER BY title_type, decade;

-- Rating trends by genre over time
-- Purpose: See how different genres have performed across decades
SELECT 
    g.name AS genre,
    FLOOR(t.start_year / 10) * 10 AS decade,
    AVG(r.average_rating) AS avg_rating,
    COUNT(*) AS title_count,
    STDDEV(r.average_rating) AS rating_stddev
FROM titles t
JOIN ratings r ON t.id = r.title_id
JOIN title_genres tg ON t.id = tg.title_id
JOIN genres g ON tg.genre_id = g.id
WHERE t.start_year IS NOT NULL 
    AND t.start_year >= 1970
    AND r.num_votes >= 50
GROUP BY g.name, FLOOR(t.start_year / 10) * 10
HAVING COUNT(*) >= 10  -- Only include genres with enough data
ORDER BY genre, decade;

-- ===============================
-- 2. PERFORMANCE ANALYSIS
-- ===============================

-- Directors' performance analysis with career progression
-- Purpose: Analyze directors' average ratings and career trends
WITH director_stats AS (
    SELECT 
        p.id,
        p.name,
        COUNT(*) AS total_movies,
        AVG(r.average_rating) AS avg_rating,
        STDDEV(r.average_rating) AS rating_consistency,
        MIN(t.start_year) AS career_start,
        MAX(t.start_year) AS career_end,
        SUM(r.num_votes) AS total_votes,
        -- Calculate ratings trend over career
        REGR_SLOPE(r.average_rating, t.start_year) AS rating_trend
    FROM people p
    JOIN title_people tp ON p.id = tp.person_id
    JOIN titles t ON tp.title_id = t.id
    JOIN ratings r ON t.id = r.title_id
    WHERE tp.category = 'director'
        AND t.title_type = 'movie'
        AND r.num_votes >= 100
    GROUP BY p.id, p.name
    HAVING COUNT(*) >= 5  -- Directors with at least 5 movies
),
director_rankings AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (ORDER BY avg_rating DESC, total_votes DESC) AS rating_rank,
        ROW_NUMBER() OVER (ORDER BY total_movies DESC) AS productivity_rank,
        -- Career length in years
        (career_end - career_start + 1) AS career_length
    FROM director_stats
)
SELECT 
    name,
    total_movies,
    ROUND(avg_rating, 2) AS avg_rating,
    ROUND(rating_consistency, 2) AS consistency,
    career_start,
    career_end,
    career_length,
    total_votes,
    rating_rank,
    productivity_rank,
    CASE 
        WHEN rating_trend > 0.05 THEN 'Improving'
        WHEN rating_trend < -0.05 THEN 'Declining' 
        ELSE 'Stable'
    END AS career_trajectory
FROM director_rankings
ORDER BY avg_rating DESC, total_votes DESC
LIMIT 50;

-- Actor success analysis with genre preferences
-- Purpose: Analyze actors' filmography success and genre specialization
WITH actor_genre_analysis AS (
    SELECT 
        p.id,
        p.name,
        g.name AS genre,
        COUNT(*) AS movies_in_genre,
        AVG(r.average_rating) AS avg_rating_in_genre,
        SUM(r.num_votes) AS total_votes_in_genre
    FROM people p
    JOIN title_people tp ON p.id = tp.person_id
    JOIN titles t ON tp.title_id = t.id
    JOIN ratings r ON t.id = r.title_id
    JOIN title_genres tg ON t.id = tg.title_id
    JOIN genres g ON tg.genre_id = g.id
    WHERE tp.category IN ('actor', 'actress')
        AND t.title_type = 'movie'
        AND r.num_votes >= 100
    GROUP BY p.id, p.name, g.name
),
actor_overall_stats AS (
    SELECT 
        p.id,
        p.name,
        COUNT(*) AS total_movies,
        AVG(r.average_rating) AS overall_avg_rating,
        SUM(r.num_votes) AS total_career_votes
    FROM people p
    JOIN title_people tp ON p.id = tp.person_id
    JOIN titles t ON tp.title_id = t.id
    JOIN ratings r ON t.id = r.title_id
    WHERE tp.category IN ('actor', 'actress')
        AND t.title_type = 'movie'
        AND r.num_votes >= 100
    GROUP BY p.id, p.name
    HAVING COUNT(*) >= 10  -- Actors with substantial filmography
)
SELECT 
    aos.name,
    aos.total_movies,
    ROUND(aos.overall_avg_rating, 2) AS avg_rating,
    aos.total_career_votes,
    -- Find actor's best genre
    aga_best.genre AS best_genre,
    aga_best.movies_in_genre AS movies_in_best_genre,
    ROUND(aga_best.avg_rating_in_genre, 2) AS best_genre_rating
FROM actor_overall_stats aos
LEFT JOIN LATERAL (
    SELECT genre, movies_in_genre, avg_rating_in_genre
    FROM actor_genre_analysis aga
    WHERE aga.id = aos.id
    ORDER BY avg_rating_in_genre DESC, movies_in_genre DESC
    LIMIT 1
) aga_best ON true
ORDER BY aos.overall_avg_rating DESC, aos.total_career_votes DESC
LIMIT 100;

-- Genre popularity trends over time
-- Purpose: Track how genre preferences have shifted across decades
WITH genre_decade_stats AS (
    SELECT 
        g.name AS genre,
        FLOOR(t.start_year / 10) * 10 AS decade,
        COUNT(*) AS title_count,
        AVG(r.average_rating) AS avg_rating,
        SUM(r.num_votes) AS popularity_score
    FROM genres g
    JOIN title_genres tg ON g.id = tg.genre_id
    JOIN titles t ON tg.title_id = t.id
    LEFT JOIN ratings r ON t.id = r.title_id
    WHERE t.start_year IS NOT NULL 
        AND t.start_year >= 1970
        AND t.title_type = 'movie'
    GROUP BY g.name, FLOOR(t.start_year / 10) * 10
)
SELECT 
    genre,
    decade,
    title_count,
    ROUND(avg_rating, 2) AS avg_rating,
    popularity_score,
    -- Calculate percentage of total movies in that decade
    ROUND(100.0 * title_count / SUM(title_count) OVER (PARTITION BY decade), 2) AS decade_percentage,
    -- Show growth vs previous decade
    LAG(title_count) OVER (PARTITION BY genre ORDER BY decade) AS prev_decade_count,
    ROUND(100.0 * (title_count - LAG(title_count) OVER (PARTITION BY genre ORDER BY decade)) / 
          NULLIF(LAG(title_count) OVER (PARTITION BY genre ORDER BY decade), 0), 1) AS growth_rate
FROM genre_decade_stats
ORDER BY genre, decade;

-- ===============================
-- 3. RELATIONSHIP ANALYSIS  
-- ===============================

-- Collaboration networks - find frequent collaborators
-- Purpose: Identify directors and actors who frequently work together
WITH director_actor_pairs AS (
    SELECT 
        d.person_id AS director_id,
        dp.name AS director_name,
        a.person_id AS actor_id,
        ap.name AS actor_name,
        COUNT(*) AS collaboration_count,
        AVG(r.average_rating) AS avg_collaboration_rating,
        ARRAY_AGG(t.primary_title ORDER BY t.start_year) AS movies_together
    FROM title_people d
    JOIN title_people a ON d.title_id = a.title_id
    JOIN people dp ON d.person_id = dp.id
    JOIN people ap ON a.person_id = ap.id
    JOIN titles t ON d.title_id = t.id
    LEFT JOIN ratings r ON t.id = r.title_id
    WHERE d.category = 'director'
        AND a.category IN ('actor', 'actress')
        AND t.title_type = 'movie'
        AND d.person_id != a.person_id
    GROUP BY d.person_id, dp.name, a.person_id, ap.name
    HAVING COUNT(*) >= 3  -- At least 3 collaborations
)
SELECT 
    director_name,
    actor_name,
    collaboration_count,
    ROUND(avg_collaboration_rating, 2) AS avg_rating,
    movies_together[1:3] AS sample_movies  -- Show first 3 movies
FROM director_actor_pairs
ORDER BY collaboration_count DESC, avg_collaboration_rating DESC
LIMIT 50;

-- Genre combination analysis
-- Purpose: Find which genre combinations work well together
WITH genre_combinations AS (
    SELECT 
        g1.name AS genre1,
        g2.name AS genre2,
        COUNT(*) AS combination_count,
        AVG(r.average_rating) AS avg_rating,
        SUM(r.num_votes) AS total_popularity
    FROM title_genres tg1
    JOIN title_genres tg2 ON tg1.title_id = tg2.title_id AND tg1.genre_id < tg2.genre_id
    JOIN genres g1 ON tg1.genre_id = g1.id
    JOIN genres g2 ON tg2.genre_id = g2.id
    JOIN titles t ON tg1.title_id = t.id
    LEFT JOIN ratings r ON t.id = r.title_id
    WHERE t.title_type = 'movie'
    GROUP BY g1.name, g2.name
    HAVING COUNT(*) >= 20  -- Combinations with sufficient data
)
SELECT 
    genre1,
    genre2,
    combination_count,
    ROUND(avg_rating, 2) AS avg_rating,
    total_popularity,
    -- Rank combinations by success
    ROW_NUMBER() OVER (ORDER BY avg_rating DESC, total_popularity DESC) AS success_rank
FROM genre_combinations
ORDER BY avg_rating DESC, total_popularity DESC
LIMIT 30;

-- Success patterns - what makes a highly rated movie?
-- Purpose: Analyze characteristics of top-rated movies
WITH success_analysis AS (
    SELECT 
        t.id,
        t.primary_title,
        t.start_year,
        t.runtime_minutes,
        r.average_rating,
        r.num_votes,
        -- Count genres per movie
        COUNT(DISTINCT tg.genre_id) AS genre_count,
        -- Count cast size
        COUNT(DISTINCT CASE WHEN tp.category IN ('actor', 'actress') THEN tp.person_id END) AS cast_size,
        -- Count crew size
        COUNT(DISTINCT CASE WHEN tp.category NOT IN ('actor', 'actress') THEN tp.person_id END) AS crew_size
    FROM titles t
    JOIN ratings r ON t.id = r.title_id
    LEFT JOIN title_genres tg ON t.id = tg.title_id
    LEFT JOIN title_people tp ON t.id = tp.title_id
    WHERE t.title_type = 'movie'
        AND r.num_votes >= 1000  -- Movies with significant voting
    GROUP BY t.id, t.primary_title, t.start_year, t.runtime_minutes, r.average_rating, r.num_votes
),
rating_quartiles AS (
    SELECT 
        *,
        NTILE(4) OVER (ORDER BY average_rating) AS rating_quartile
    FROM success_analysis
)
SELECT 
    rating_quartile,
    COUNT(*) AS movie_count,
    ROUND(AVG(average_rating), 2) AS avg_rating,
    ROUND(AVG(runtime_minutes), 0) AS avg_runtime,
    ROUND(AVG(genre_count), 1) AS avg_genres,
    ROUND(AVG(cast_size), 0) AS avg_cast_size,
    ROUND(AVG(crew_size), 0) AS avg_crew_size,
    ROUND(AVG(num_votes), 0) AS avg_votes
FROM rating_quartiles
GROUP BY rating_quartile
ORDER BY rating_quartile DESC;

-- ===============================
-- 4. CUSTOM ANALYSIS: TV SERIES LONGEVITY
-- Purpose: Analyze what factors contribute to long-running successful TV series
-- ===============================

WITH series_longevity_analysis AS (
    SELECT 
        t.id,
        t.primary_title,
        t.start_year,
        t.end_year,
        r.average_rating,
        r.num_votes,
        COUNT(DISTINCT e.season_number) AS total_seasons,
        COUNT(DISTINCT e.episode_id) AS total_episodes,
        -- Calculate series duration
        COALESCE(t.end_year, EXTRACT(YEAR FROM CURRENT_DATE)::INT) - t.start_year + 1 AS series_duration,
        -- Calculate episodes per season average
        ROUND(COUNT(DISTINCT e.episode_id)::NUMERIC / NULLIF(COUNT(DISTINCT e.season_number), 0), 1) AS avg_episodes_per_season
    FROM titles t
    LEFT JOIN episodes e ON t.id = e.parent_series_id
    LEFT JOIN ratings r ON t.id = r.title_id
    WHERE t.title_type = 'tvSeries'
        AND t.start_year IS NOT NULL
    GROUP BY t.id, t.primary_title, t.start_year, t.end_year, r.average_rating, r.num_votes
    HAVING COUNT(DISTINCT e.season_number) >= 1  -- Has episode data
),
longevity_categories AS (
    SELECT 
        *,
        CASE 
            WHEN total_seasons >= 10 THEN 'Long-running (10+ seasons)'
            WHEN total_seasons >= 5 THEN 'Medium-run (5-9 seasons)'
            WHEN total_seasons >= 2 THEN 'Short-run (2-4 seasons)'
            ELSE 'Single season'
        END AS longevity_category,
        CASE
            WHEN average_rating >= 8.5 THEN 'Excellent'
            WHEN average_rating >= 7.5 THEN 'Good'
            WHEN average_rating >= 6.5 THEN 'Average'
            ELSE 'Below Average'
        END AS quality_tier
    FROM series_longevity_analysis
    WHERE average_rating IS NOT NULL
)
SELECT 
    longevity_category,
    quality_tier,
    COUNT(*) AS series_count,
    ROUND(AVG(average_rating), 2) AS avg_rating,
    ROUND(AVG(total_seasons), 1) AS avg_seasons,
    ROUND(AVG(series_duration), 1) AS avg_duration_years,
    ROUND(AVG(avg_episodes_per_season), 1) AS avg_eps_per_season,
    ROUND(AVG(num_votes), 0) AS avg_popularity
FROM longevity_categories
GROUP BY longevity_category, quality_tier
ORDER BY 
    CASE longevity_category
        WHEN 'Long-running (10+ seasons)' THEN 1
        WHEN 'Medium-run (5-9 seasons)' THEN 2
        WHEN 'Short-run (2-4 seasons)' THEN 3
        ELSE 4
    END,
    CASE quality_tier
        WHEN 'Excellent' THEN 1
        WHEN 'Good' THEN 2
        WHEN 'Average' THEN 3
        ELSE 4
    END;

-- Detailed look at most successful long-running series
SELECT 
    primary_title,
    start_year,
    end_year,
    total_seasons,
    total_episodes,
    series_duration,
    ROUND(average_rating, 1) AS rating,
    num_votes,
    longevity_category,
    quality_tier
FROM longevity_categories
WHERE longevity_category = 'Long-running (10+ seasons)'
    AND quality_tier IN ('Excellent', 'Good')
ORDER BY average_rating DESC, num_votes DESC
LIMIT 20;

-- ===============================
-- 5. ADVANCED WINDOW FUNCTIONS ANALYSIS
-- ===============================

-- Career trajectory analysis using window functions
-- Purpose: Track how individual careers evolve over time
WITH career_progression AS (
    SELECT 
        p.id,
        p.name,
        t.primary_title,
        t.start_year,
        r.average_rating,
        r.num_votes,
        tp.category,
        -- Running average of ratings throughout career
        AVG(r.average_rating) OVER (
            PARTITION BY p.id 
            ORDER BY t.start_year 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS career_running_avg,
        -- Rating compared to person's career average
        r.average_rating - AVG(r.average_rating) OVER (PARTITION BY p.id) AS rating_vs_career_avg,
        -- Rank movies within person's career
        ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY t.start_year) AS career_movie_number,
        -- Peak rating in career so far
        MAX(r.average_rating) OVER (
            PARTITION BY p.id 
            ORDER BY t.start_year 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS career_peak_so_far,
        -- Movies since last hit (rating > 7.5)
        COUNT(*) OVER (
            PARTITION BY p.id, rating_group.group_id
            ORDER BY t.start_year
        ) AS movies_since_last_hit
    FROM people p
    JOIN title_people tp ON p.id = tp.person_id
    JOIN titles t ON tp.title_id = t.id
    JOIN ratings r ON t.id = r.title_id
    LEFT JOIN LATERAL (
        SELECT SUM(CASE WHEN r.average_rating > 7.5 THEN 1 ELSE 0 END) 
               OVER (PARTITION BY p.id ORDER BY t.start_year) AS group_id
    ) rating_group ON true
    WHERE tp.category = 'director'
        AND t.title_type = 'movie'
        AND r.num_votes >= 100
)
SELECT 
    name,
    primary_title,
    start_year,
    ROUND(average_rating, 1) AS rating,
    ROUND(career_running_avg, 2) AS running_avg,
    ROUND(rating_vs_career_avg, 2) AS vs_career_avg,
    career_movie_number,
    ROUND(career_peak_so_far, 1) AS peak_so_far
FROM career_progression
WHERE name IN (
    SELECT name FROM (
        SELECT name, COUNT(*) as movie_count
        FROM career_progression 
        GROUP BY name 
        HAVING COUNT(*) >= 8
        ORDER BY AVG(average_rating) DESC 
        LIMIT 10
    ) top_directors
)
ORDER BY name, start_year;

-- ===============================
-- 6. COMPLEX AGGREGATION WITH HAVING
-- ===============================

-- Genre performance analysis with complex conditions
-- Purpose: Find genres that consistently produce quality content
WITH genre_performance AS (
    SELECT 
        g.name AS genre,
        COUNT(*) AS total_titles,
        AVG(r.average_rating) AS avg_rating,
        STDDEV(r.average_rating) AS rating_stddev,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY r.average_rating) AS q1_rating,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY r.average_rating) AS q3_rating,
        COUNT(CASE WHEN r.average_rating >= 8.0 THEN 1 END) AS excellent_count,
        COUNT(CASE WHEN r.average_rating <= 5.0 THEN 1 END) AS poor_count,
        SUM(r.num_votes) AS total_popularity,
        MIN(t.start_year) AS first_appearance,
        MAX(t.start_year) AS last_appearance
    FROM genres g
    JOIN title_genres tg ON g.id = tg.genre_id
    JOIN titles t ON tg.title_id = t.id
    JOIN ratings r ON t.id = r.title_id
    WHERE t.title_type = 'movie'
        AND r.num_votes >= 50
        AND t.start_year >= 1980
    GROUP BY g.name
    HAVING 
        COUNT(*) >= 100  -- Minimum sample size
        AND AVG(r.average_rating) >= 6.0  -- Decent average quality
        AND STDDEV(r.average_rating) <= 1.5  -- Reasonable consistency
        AND COUNT(CASE WHEN r.average_rating >= 8.0 THEN 1 END) >= 5  -- Some excellent titles
)
SELECT 
    genre,
    total_titles,
    ROUND(avg_rating, 2) AS avg_rating,
    ROUND(rating_stddev, 2) AS consistency,
    ROUND(q1_rating, 1) AS q1_rating,
    ROUND(q3_rating, 1) AS q3_rating,
    excellent_count,
    poor_count,
    ROUND(100.0 * excellent_count / total_titles, 1) AS excellent_percentage,
    total_popularity,
    last_appearance - first_appearance + 1 AS genre_lifespan
FROM genre_performance
ORDER BY avg_rating DESC, total_titles DESC;

-- ===============================
-- 7. PERFORMANCE OPTIMIZATION QUERIES
-- ===============================

-- Most voted titles analysis (optimized with proper indexing)
-- Purpose: Analyze the most popular content and voting patterns
SELECT 
    t.title_type,
    t.primary_title,
    t.start_year,
    r.average_rating,
    r.num_votes,
    STRING_AGG(g.name, ', ' ORDER BY g.name) AS genres,
    -- Calculate popularity rank within type and year
    RANK() OVER (
        PARTITION BY t.title_type, t.start_year 
        ORDER BY r.num_votes DESC
    ) AS year_popularity_rank
FROM titles t
JOIN ratings r ON t.id = r.title_id
LEFT JOIN title_genres tg ON t.id = tg.title_id
LEFT JOIN genres g ON tg.genre_id = g.id
WHERE r.num_votes >= 10000  -- High-voted content only
GROUP BY t.id, t.title_type, t.primary_title, t.start_year, r.average_rating, r.num_votes
ORDER BY r.num_votes DESC
LIMIT 100;

-- ===============================
-- Summary Statistics for Dashboard
-- ===============================

-- Overall database statistics
-- Purpose: Provide summary metrics for reporting dashboard
SELECT 
    'Total Movies' AS metric,
    COUNT(*)::TEXT AS value
FROM titles WHERE title_type = 'movie'

UNION ALL

SELECT 
    'Total TV Series' AS metric,
    COUNT(*)::TEXT AS value
FROM titles WHERE title_type = 'tvSeries'

UNION ALL

SELECT 
    'Total Episodes' AS metric,
    COUNT(*)::TEXT AS value
FROM titles WHERE title_type = 'tvEpisode'

UNION ALL

SELECT 
    'Total People' AS metric,
    COUNT(*)::TEXT AS value
FROM people

UNION ALL

SELECT 
    'Average Movie Rating' AS metric,
    ROUND(AVG(r.average_rating), 2)::TEXT AS value
FROM titles t
JOIN ratings r ON t.id = r.title_id
WHERE t.title_type = 'movie'

UNION ALL

SELECT 
    'Average TV Series Rating' AS metric,
    ROUND(AVG(r.average_rating), 2)::TEXT AS value
FROM titles t
JOIN ratings r ON t.id = r.title_id
WHERE t.title_type = 'tvSeries'

UNION ALL

SELECT 
    'Most Popular Genre' AS metric,
    g.name AS value
FROM genres g
JOIN title_genres tg ON g.id = tg.genre_id
GROUP BY g.name
ORDER BY COUNT(*) DESC
LIMIT 1;