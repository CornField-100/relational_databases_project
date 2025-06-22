-- init.sql — IMDb schema (final version with TEXT ids)

-- Titles (movies, series, episodes)
CREATE TABLE titles (
    id TEXT PRIMARY KEY, -- IMDb tconst (e.g. tt0111161)
    title_type VARCHAR(20) NOT NULL,
    primary_title TEXT NOT NULL,
    original_title TEXT,
    start_year INT,
    end_year INT,
    runtime_minutes INT,
    is_adult BOOLEAN DEFAULT FALSE
);

-- Extended title metadata
CREATE TABLE title_details (
    title_id TEXT PRIMARY KEY REFERENCES titles(id),
    production_company TEXT,
    alternative_titles TEXT[],
    languages TEXT[],
    countries TEXT[]
);

-- Episode relationships
CREATE TABLE episodes (
    episode_id TEXT PRIMARY KEY REFERENCES titles(id),
    parent_series_id TEXT REFERENCES titles(id),
    season_number INT,
    episode_number INT
);

-- People (IMDb nconst)
CREATE TABLE people (
    id TEXT PRIMARY KEY, -- IMDb nconst (e.g. nm0000001)
    name TEXT NOT NULL,
    birth_year INT,
    death_year INT
);

-- Cast/crew roles
CREATE TABLE title_people (
    title_id TEXT REFERENCES titles(id),
    person_id TEXT REFERENCES people(id),
    category TEXT,       -- actor, director, writer, etc.
    job TEXT,
    characters TEXT,
    PRIMARY KEY (title_id, person_id, category)
);

-- Genre master list
CREATE TABLE genres (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
);

-- Title-genre relationships
CREATE TABLE title_genres (
    title_id TEXT REFERENCES titles(id),
    genre_id INT REFERENCES genres(id),
    PRIMARY KEY (title_id, genre_id)
);

-- IMDb ratings
CREATE TABLE ratings (
    title_id TEXT PRIMARY KEY REFERENCES titles(id),
    average_rating NUMERIC(3,1),
    num_votes INT
);

-- Indexes to improve performance
CREATE INDEX idx_title_type       ON titles(title_type);
CREATE INDEX idx_primary_title    ON titles(primary_title);
CREATE INDEX idx_person_name      ON people(name);
CREATE INDEX idx_genre_name       ON genres(name);
CREATE INDEX idx_rating_avg       ON ratings(average_rating);
