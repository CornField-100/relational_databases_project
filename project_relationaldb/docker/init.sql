-- schema.sql

CREATE TABLE titles (
    id SERIAL PRIMARY KEY,
    title_type VARCHAR(20) NOT NULL, -- movie, tvSeries, tvEpisode
    primary_title TEXT NOT NULL,
    original_title TEXT,
    start_year INT,
    end_year INT,
    runtime_minutes INT,
    is_adult BOOLEAN DEFAULT FALSE
);

CREATE TABLE title_details (
    title_id INT PRIMARY KEY REFERENCES titles(id),
    production_company TEXT,
    alternative_titles TEXT[],
    languages TEXT[],
    countries TEXT[]
);

CREATE TABLE episodes (
    episode_id INT PRIMARY KEY REFERENCES titles(id),
    parent_series_id INT REFERENCES titles(id),
    season_number INT,
    episode_number INT
);

CREATE TABLE people (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    birth_year INT,
    death_year INT
);

CREATE TABLE title_people (
    title_id INT REFERENCES titles(id),
    person_id INT REFERENCES people(id),
    role_type VARCHAR(20), -- actor, director, writer
    character_name TEXT,
    PRIMARY KEY (title_id, person_id, role_type)
);

CREATE TABLE genres (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
);

CREATE TABLE title_genres (
    title_id INT REFERENCES titles(id),
    genre_id INT REFERENCES genres(id),
    PRIMARY KEY (title_id, genre_id)
);

CREATE TABLE ratings (
    title_id INT PRIMARY KEY REFERENCES titles(id),
    average_rating NUMERIC(3,1),
    num_votes INT
);

-- Indexes to improve performance
CREATE INDEX idx_title_type ON titles(title_type);
CREATE INDEX idx_primary_title ON titles(primary_title);
CREATE INDEX idx_person_name ON people(name);
CREATE INDEX idx_genre_name ON genres(name);
CREATE INDEX idx_rating_avg ON ratings(average_rating);
