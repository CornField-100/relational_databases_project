-- ===================================================
-- Part 2: Web Application Queries
-- ===================================================

-- ===============================
-- 1. Movie Summary Page
-- Purpose: Display key information for a movie including cast, crew, and ratings
-- ===============================
SELECT 
    t.id,
    t.primary_title,
    t.original_title,
    t.start_year,
    t.runtime_minutes,
    r.average_rating,
    r.num_votes,
    -- Get directors (concatenated)
    STRING_AGG(DISTINCT CASE WHEN tp.category = 'director' THEN p.name END, ', ') AS directors,
    -- Get writers (concatenated)  
    STRING_AGG(DISTINCT CASE WHEN tp.category = 'writer' THEN p.name END, ', ') AS writers,
    -- Get genres (concatenated)
    STRING_AGG(DISTINCT g.name, ', ') AS genres
FROM titles t
LEFT JOIN ratings r ON t.id = r.title_id
LEFT JOIN title_people tp ON t.id = tp.title_id
LEFT JOIN people p ON tp.person_id = p.id
LEFT JOIN title_genres tg ON t.id = tg.title_id
LEFT JOIN genres g ON tg.genre_id = g.id
WHERE t.id = $1 AND t.title_type = 'movie'
GROUP BY t.id, t.primary_title, t.original_title, t.start_year, t.runtime_minutes, r.average_rating, r.num_votes;

-- Get top 5 main cast for movie summary
SELECT 
    p.name,
    tp.characters
FROM title_people tp
JOIN people p ON tp.person_id = p.id
WHERE tp.title_id = $1 AND tp.category = 'actor'
ORDER BY tp.title_id, tp.person_id -- Using available ordering
LIMIT 5;

-- ===============================
-- 2. Movie Details Page  
-- Purpose: Show detailed production information and alternative titles
-- ===============================
SELECT 
    t.*,
    td.production_company,
    td.alternative_titles,
    td.languages,
    td.countries,
    r.average_rating,
    r.num_votes
FROM titles t
LEFT JOIN title_details td ON t.id = td.title_id
LEFT JOIN ratings r ON t.id = r.title_id
WHERE t.id = $1 AND t.title_type = 'movie';

-- ===============================
-- 3. Complete Cast/Crew Page
-- Purpose: Show all cast and crew members organized by category
-- ===============================
SELECT 
    tp.category,
    p.name,
    tp.job,
    tp.characters,
    p.birth_year,
    p.death_year
FROM title_people tp
JOIN people p ON tp.person_id = p.id
WHERE tp.title_id = $1
ORDER BY 
    CASE tp.category 
        WHEN 'director' THEN 1
        WHEN 'writer' THEN 2  
        WHEN 'producer' THEN 3
        WHEN 'actor' THEN 4
        WHEN 'actress' THEN 4
        ELSE 5
    END,
    p.name;

-- ===============================
-- 4. TV Series Summary Page
-- Purpose: Display series overview with season count and main cast
-- ===============================
SELECT 
    t.id,
    t.primary_title,
    t.start_year,
    t.end_year,
    r.average_rating,
    r.num_votes,
    -- Count seasons
    COUNT(DISTINCT e.season_number) AS season_count,
    -- Count total episodes
    COUNT(DISTINCT e.episode_id) AS episode_count,
    -- Get genres
    STRING_AGG(DISTINCT g.name, ', ') AS genres
FROM titles t
LEFT JOIN episodes e ON t.id = e.parent_series_id
LEFT JOIN ratings r ON t.id = r.title_id
LEFT JOIN title_genres tg ON t.id = tg.title_id
LEFT JOIN genres g ON tg.genre_id = g.id
WHERE t.id = $1 AND t.title_type = 'tvSeries'
GROUP BY t.id, t.primary_title, t.start_year, t.end_year, r.average_rating, r.num_votes;

-- Get main cast for TV series
SELECT 
    p.name,
    tp.characters
FROM title_people tp
JOIN people p ON tp.person_id = p.id
WHERE tp.title_id = $1 AND tp.category IN ('actor', 'actress')
ORDER BY p.name
LIMIT 10;

-- ===============================
-- 5. TV Series Details Page
-- Purpose: Season-by-season breakdown with episode information
-- ===============================
SELECT 
    e.season_number,
    COUNT(*) AS episode_count,
    MIN(et.start_year) AS season_start_year,
    AVG(r.average_rating) AS avg_season_rating,
    SUM(r.num_votes) AS total_votes
FROM episodes e
JOIN titles et ON e.episode_id = et.id
LEFT JOIN ratings r ON e.episode_id = r.title_id
WHERE e.parent_series_id = $1
GROUP BY e.season_number
ORDER BY e.season_number;

-- ===============================
-- 6. Episode Page
-- Purpose: Show specific episode details including guest stars
-- ===============================
SELECT 
    t.primary_title,
    t.start_year,
    e.season_number,
    e.episode_number,
    r.average_rating,
    r.num_votes,
    -- Get series title
    series.primary_title AS series_title
FROM titles t
JOIN episodes e ON t.id = e.episode_id
JOIN titles series ON e.parent_series_id = series.id
LEFT JOIN ratings r ON t.id = r.title_id
WHERE t.id = $1;

-- Get episode cast (including guest stars)
SELECT 
    p.name,
    tp.characters,
    tp.category
FROM title_people tp
JOIN people p ON tp.person_id = p.id
WHERE tp.title_id = $1 AND tp.category IN ('actor', 'actress')
ORDER BY p.name;

-- ===============================
-- 7. Person Page
-- Purpose: Show person's complete filmography categorized by role
-- ===============================
SELECT 
    p.name,
    p.birth_year,
    p.death_year
FROM people p
WHERE p.id = $1;

-- Get person's filmography
SELECT 
    t.primary_title,
    t.title_type,
    t.start_year,
    tp.category,
    tp.job,
    tp.characters,
    r.average_rating
FROM title_people tp
JOIN titles t ON tp.title_id = t.id
LEFT JOIN ratings r ON t.id = r.title_id
WHERE tp.person_id = $1
ORDER BY 
    tp.category,
    t.start_year DESC NULLS LAST,
    t.primary_title;

-- ===============================
-- 8. Movie Listing Page with Filters
-- Purpose: Browseable movie list with genre, year, rating filters
-- ===============================
SELECT 
    t.id,
    t.primary_title,
    t.start_year,
    t.runtime_minutes,
    r.average_rating,
    r.num_votes,
    STRING_AGG(DISTINCT g.name, ', ') AS genres
FROM titles t
LEFT JOIN ratings r ON t.id = r.title_id
LEFT JOIN title_genres tg ON t.id = tg.title_id
LEFT JOIN genres g ON tg.genre_id = g.id
WHERE t.title_type = 'movie'
    AND ($2::INT IS NULL OR t.start_year = $2)  -- Year filter
    AND ($3::TEXT IS NULL OR EXISTS (  -- Genre filter
        SELECT 1 FROM title_genres tg2
        JOIN genres g2 ON tg2.genre_id = g2.id
        WHERE tg2.title_id = t.id AND g2.name = $3
    ))
    AND ($4::NUMERIC IS NULL OR r.average_rating >= $4)  -- Minimum rating filter
    AND ($5::BOOLEAN IS NULL OR t.is_adult = $5)  -- Adult content filter
GROUP BY t.id, t.primary_title, t.start_year, t.runtime_minutes, r.average_rating, r.num_votes
ORDER BY 
    CASE WHEN $6 = 'rating' THEN r.average_rating END DESC NULLS LAST,
    CASE WHEN $6 = 'year' THEN t.start_year END DESC NULLS LAST,
    CASE WHEN $6 = 'title' THEN t.primary_title END ASC,
    r.num_votes DESC NULLS LAST
LIMIT $7 OFFSET $8;

-- ===============================
-- 9. TV Series Listing Page  
-- Purpose: Browseable series list with similar filters plus TV-specific options
-- ===============================
SELECT 
    t.id,
    t.primary_title,
    t.start_year,
    t.end_year,
    r.average_rating,
    r.num_votes,
    COUNT(DISTINCT e.season_number) AS season_count,
    STRING_AGG(DISTINCT g.name, ', ') AS genres
FROM titles t
LEFT JOIN ratings r ON t.id = r.title_id  
LEFT JOIN episodes e ON t.id = e.parent_series_id
LEFT JOIN title_genres tg ON t.id = tg.title_id
LEFT JOIN genres g ON tg.genre_id = g.id
WHERE t.title_type = 'tvSeries'
    AND ($2::INT IS NULL OR t.start_year >= $2)  -- Start year filter
    AND ($3::INT IS NULL OR t.end_year <= $3 OR t.end_year IS NULL)  -- End year filter
    AND ($4::TEXT IS NULL OR EXISTS (  -- Genre filter
        SELECT 1 FROM title_genres tg2
        JOIN genres g2 ON tg2.genre_id = g2.id
        WHERE tg2.title_id = t.id AND g2.name = $4
    ))
    AND ($5::NUMERIC IS NULL OR r.average_rating >= $5)  -- Minimum rating filter
    AND ($6::BOOLEAN IS NULL OR t.is_adult = $6)  -- Adult content filter
GROUP BY t.id, t.primary_title, t.start_year, t.end_year, r.average_rating, r.num_votes
HAVING ($7::INT IS NULL OR COUNT(DISTINCT e.season_number) >= $7)  -- Minimum seasons filter
ORDER BY 
    CASE WHEN $8 = 'rating' THEN r.average_rating END DESC NULLS LAST,
    CASE WHEN $8 = 'year' THEN t.start_year END DESC NULLS LAST,
    CASE WHEN $8 = 'title' THEN t.primary_title END ASC,
    r.num_votes DESC NULLS LAST
LIMIT $9 OFFSET $10;

-- ===============================
-- 10. Home Page - Featured Content
-- Purpose: Get featured movies and series for homepage
-- ===============================
-- Top rated movies (min 1000 votes)
SELECT 
    t.id,
    t.primary_title,
    t.start_year,
    r.average_rating,
    r.num_votes,
    'movie' as content_type
FROM titles t
JOIN ratings r ON t.id = r.title_id
WHERE t.title_type = 'movie' 
    AND r.num_votes >= 1000
    AND ($1::BOOLEAN IS NULL OR t.is_adult = $1)  -- Adult filter
ORDER BY r.average_rating DESC, r.num_votes DESC
LIMIT 10;

-- Top rated TV series (min 500 votes)
SELECT 
    t.id,
    t.primary_title,
    t.start_year,
    r.average_rating,
    r.num_votes,
    'tvSeries' as content_type
FROM titles t
JOIN ratings r ON t.id = r.title_id
WHERE t.title_type = 'tvSeries'
    AND r.num_votes >= 500
    AND ($1::BOOLEAN IS NULL OR t.is_adult = $1)  -- Adult filter
ORDER BY r.average_rating DESC, r.num_votes DESC
LIMIT 10;

-- ===============================
-- ADVANCED FEATURES
-- ===============================

-- Search Engine Query
-- Purpose: Full-text search across titles and people
SELECT 
    'title' as result_type,
    t.id,
    t.primary_title as name,
    t.title_type,
    t.start_year,
    r.average_rating,
    NULL as birth_year
FROM titles t
LEFT JOIN ratings r ON t.id = r.title_id
WHERE 
    t.primary_title ILIKE '%' || $1 || '%' 
    OR t.original_title ILIKE '%' || $1 || '%'
    AND ($2::BOOLEAN IS NULL OR t.is_adult = $2)

UNION ALL

SELECT 
    'person' as result_type,
    p.id,
    p.name,
    NULL as title_type,
    NULL as start_year,
    NULL as average_rating,
    p.birth_year
FROM people p
WHERE p.name ILIKE '%' || $1 || '%'

ORDER BY 
    result_type,
    CASE WHEN result_type = 'title' THEN average_rating END DESC NULLS LAST,
    name
LIMIT 50;

-- Get available genres for filter dropdowns
SELECT id, name FROM genres ORDER BY name;

-- Get year range for filter sliders  
SELECT 
    MIN(start_year) as min_year,
    MAX(start_year) as max_year
FROM titles 
WHERE start_year IS NOT NULL;