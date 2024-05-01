DROP TABLE ingredients_recipes;
DROP TABLE recipe_steps;
DROP TABLE recipes;
DROP TABLE ingredients;
DROP TABLE users;


CREATE TABLE users (
  id serial PRIMARY KEY,
  username text NOT NULL UNIQUE,
  password text NOT NULL
);

CREATE TABLE recipes (
  id serial PRIMARY KEY,
  owning_user integer REFERENCES users (id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  date_last_made date
);

CREATE TABLE ingredients (
  id serial PRIMARY KEY,
  owning_user integer REFERENCES users (id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  cost numeric,
  amount_in_pantry text
);

CREATE TABLE ingredients_recipes (
  id serial PRIMARY KEY,
  recipe_id integer REFERENCES recipes (id) ON DELETE CASCADE NOT NULL,
  ingredient_id integer REFERENCES ingredients (id) ON DELETE CASCADE NOT NULL,
  ingredient_amount text,
  UNIQUE (recipe_id, ingredient_id)
);

CREATE TABLE recipe_steps (
  id serial PRIMARY KEY,
  recipe_id integer REFERENCES recipes (id) ON DELETE CASCADE NOT NULL,
  direction text NOT NULL,
  notes text
);


INSERT INTO users (username, password)
  VALUES ('development', '$2a$12$q2blzpJlvX.Idr/bJydrjeBN/V9GNhrzEeOtw1.6Akg/9gdY6zSoe');

DO $$
DECLARE
  iterator integer := 0;
BEGIN
	WHILE (iterator < 100) LOOP
		INSERT INTO recipes (owning_user, name)
			VALUES (1, 'pagination_test_' || iterator::text);
			iterator := iterator + 1;
	END LOOP;
END$$;

DO $$
DECLARE
  iterator integer := 0;
BEGIN
	WHILE (iterator < 100) LOOP
		INSERT INTO ingredients (owning_user, name, amount_in_pantry)
			VALUES (1, 'pagination_test_' || iterator::text, '1/1');
			iterator := iterator + 1;
	END LOOP;
END$$;

DO $$
DECLARE
  iterator integer := 0;
BEGIN
	WHILE (iterator < 100) LOOP
		INSERT INTO ingredients (owning_user, name)
			VALUES (1, 'pagination_test_' || (iterator + 99)::text );
			iterator := iterator + 1;
	END LOOP;
END$$;

DO $$
DECLARE
  iterator integer := 0;
BEGIN
	WHILE (iterator < 100) LOOP
		INSERT INTO ingredients_recipes (recipe_id, ingredient_id)
			VALUES (1, iterator + 1);
			iterator := iterator + 1;
	END LOOP;
END$$;

DO $$
DECLARE
  iterator integer := 0;
BEGIN
	WHILE (iterator < 100) LOOP
		INSERT INTO recipe_steps (recipe_id, direction)
			VALUES (1, 'pagination_test_' || iterator::text);
			iterator := iterator + 1;
	END LOOP;
END$$;