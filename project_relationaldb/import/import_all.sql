-- ===================================================
-- IMDb Import Script (for use after init.sql schema)
-- ===================================================

-- Drop staging tables if they exist
DROP TABLE IF EXISTS
  import_title_basics,
  import_ratings,
  import_name_basics,
  import_principals,
  import_crew,
  import_episodes;

-- ===============================
-- 1. Title Basics
-- ===============================
CREATE TABLE import_title_basics (
  tconst TEXT,
  title_type TEXT,
  primary_title TEXT,
  original_title TEXT,
  is_adult BOOLEAN,
  start_year INT,
  end_year INT,
  runtime_minutes INT,
  genres TEXT
);

COPY import_title_basics
  FROM PROGRAM 'zcat /import/title.basics.tsv.gz'
  WITH (FORMAT csv, DELIMITER E'\t', HEADER, NULL '\N', QUOTE E'\001');

INSERT INTO titles (
  id, title_type, primary_title, original_title,
  is_adult, start_year, end_year, runtime_minutes
)
SELECT
  tconst, title_type, primary_title, original_title,
  is_adult, start_year, end_year, runtime_minutes
FROM import_title_basics
WHERE title_type IN ('movie', 'tvSeries', 'tvEpisode')
ON CONFLICT (id) DO NOTHING;

-- ===============================
-- 2. Ratings
-- ===============================
CREATE TABLE import_ratings (
  tconst TEXT,
  average_rating NUMERIC(3,1),
  num_votes INT
);

COPY import_ratings
  FROM PROGRAM 'zcat /import/title.ratings.tsv.gz'
  WITH (FORMAT csv, DELIMITER E'\t', HEADER, NULL '\N', QUOTE E'\001');

INSERT INTO ratings (title_id, average_rating, num_votes)
SELECT tconst, average_rating, num_votes
FROM import_ratings
WHERE tconst IN (SELECT id FROM titles)
ON CONFLICT (title_id) DO NOTHING;

-- ===============================
-- 3. People
-- ===============================
CREATE TABLE import_name_basics (
  nconst TEXT,
  primary_name TEXT,
  birth_year TEXT,
  death_year TEXT,
  primary_profession TEXT,
  known_for_titles TEXT
);

COPY import_name_basics
  FROM PROGRAM 'zcat /import/name.basics.tsv.gz'
  WITH (FORMAT csv, DELIMITER E'\t', HEADER, NULL '\N', QUOTE E'\001');

INSERT INTO people (id, name, birth_year, death_year)
SELECT
  nconst,
  COALESCE(primary_name, '(Unknown)'),
  NULLIF(birth_year, '')::INT,
  NULLIF(death_year, '')::INT
FROM import_name_basics
ON CONFLICT (id) DO NOTHING;

-- ===============================
-- 4. Title Principals (Cast/Crew)
-- ===============================
CREATE TABLE import_principals (
  tconst TEXT,
  ordering INT,
  nconst TEXT,
  category TEXT,
  job TEXT,
  characters TEXT
);

COPY import_principals
  FROM PROGRAM 'zcat /import/title.principals.tsv.gz'
  WITH (FORMAT csv, DELIMITER E'\t', HEADER, NULL '\N', QUOTE E'\001');

INSERT INTO title_people (title_id, person_id, category, job, characters)
SELECT
  tconst, nconst, category, job, characters
FROM import_principals
WHERE
  tconst IN (SELECT id FROM titles)
  AND nconst IN (SELECT id FROM people)
ON CONFLICT (title_id, person_id, category) DO NOTHING;

-- ===============================
-- 5. Crew (Directors & Writers)
-- ===============================
CREATE TABLE import_crew (
  tconst TEXT,
  directors TEXT,
  writers TEXT
);

COPY import_crew
  FROM PROGRAM 'zcat /import/title.crew.tsv.gz'
  WITH (FORMAT csv, DELIMITER E'\t', HEADER, NULL '\N', QUOTE E'\001');

-- Insert directors
INSERT INTO title_people (title_id, person_id, category)
SELECT c.tconst, pid, 'director'
FROM (
  SELECT tconst, unnest(string_to_array(directors, ',')) AS pid
  FROM import_crew WHERE directors IS NOT NULL
) c
WHERE c.tconst IN (SELECT id FROM titles)
  AND c.pid   IN (SELECT id FROM people)
ON CONFLICT (title_id, person_id, category) DO NOTHING;

-- Insert writers
INSERT INTO title_people (title_id, person_id, category)
SELECT c.tconst, pid, 'writer'
FROM (
  SELECT tconst, unnest(string_to_array(writers, ',')) AS pid
  FROM import_crew WHERE writers IS NOT NULL
) c
WHERE c.tconst IN (SELECT id FROM titles)
  AND c.pid   IN (SELECT id FROM people)
ON CONFLICT (title_id, person_id, category) DO NOTHING;

-- ===============================
-- 6. Episodes
-- ===============================
CREATE TABLE import_episodes (
  tconst TEXT,
  parent_tconst TEXT,
  season_number INT,
  episode_number INT
);

COPY import_episodes
  FROM PROGRAM 'zcat /import/title.episode.tsv.gz'
  WITH (FORMAT csv, DELIMITER E'\t', HEADER, NULL '\N', QUOTE E'\001');

INSERT INTO episodes (episode_id, parent_series_id, season_number, episode_number)
SELECT
  tconst,
  parent_tconst,
  season_number,
  episode_number
FROM import_episodes
WHERE
  tconst IN (SELECT id FROM titles)
  AND parent_tconst IN (SELECT id FROM titles)
ON CONFLICT (episode_id) DO NOTHING;

-- ===============================
-- Done!
-- ===============================
