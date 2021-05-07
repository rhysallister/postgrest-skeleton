DO $$
BEGIN
	RAISE NOTICE '===========================';
	RAISE NOTICE '  02-authenticty-init.sql  ';
	RAISE NOTICE '===========================';
END ;
$$ LANGUAGE PLPGSQL;


SELECT pg_reload_conf();

CREATE ROLE skltn LOGIN NOINHERIT;
CREATE ROLE everyman LOGIN NOINHERIT;
ALTER ROLE skltn PASSWORD '_dot_skltn';
GRANT everyman TO skltn;
CREATE DATABASE skltn OWNER skltn;
GRANT ALL PRIVILEGES ON DATABASE skltn TO skltn;


\c skltn
CREATE EXTENSION adminpack;
CREATE EXTENSION pg_cron;
CREATE EXTENSION postgres_fdw;
CREATE EXTENSION file_fdw;
CREATE EXTENSION pgcrypto;
CREATE EXTENSION pgjwt;
CREATE EXTENSION postgis;


CREATE SCHEMA IF NOT EXISTS authenticity;
CREATE SCHEMA IF NOT EXISTS api;
CREATE SCHEMA IF NOT EXISTS skltn;

CREATE TABLE IF NOT EXISTS authenticity.users (
	email text PRIMARY KEY check ( email ~* '^.+@.+\..+$' ),
	pass text NOT NULL check (length(pass) < 512),
	role name NOT NULL CHECK (length(pass) < 512),
	confirmed boolean NOT NULL DEFAULT False
);

CREATE TABLE IF NOT EXISTS authenticity.confirmation (
	email text PRIMARY KEY check ( email ~* '^.+@.+\..+$' ),
	confirmation_code text NOT NULL
);

CREATE OR REPLACE FUNCTION authenticity.check_role_exists() RETURNS TRIGGER AS $$
BEGIN
	IF NOT EXISTS (SELECT 1 FROM pg_roles AS r WHERE r.rolname = new.role) THEN
		RAISE foreign_key_violation USING MESSAGE = 'unknown database role: ' || new.role;
		RETURN NULL;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE PLPGSQL;

DROP TRIGGER IF EXISTS check_role_exists ON authenticity.users;
CREATE CONSTRAINT TRIGGER check_role_exists
	AFTER INSERT OR UPDATE ON authenticity.users
	FOR EACH ROW EXECUTE PROCEDURE authenticity.check_role_exists();

CREATE OR REPLACE FUNCTION authenticity.encrypt_password() RETURNS TRIGGER AS $$
BEGIN
	IF tg_op = 'INSERT' OR tg_op = 'UPDATE' THEN
		NEW.pass = crypt(NEW.pass, gen_salt('bf'));
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE PLPGSQL;

DROP TRIGGER IF EXISTS encrypt_password ON authenticity.users;
CREATE TRIGGER encrypt_password
	BEFORE INSERT OR UPDATE ON authenticity.users
	FOR EACH ROW EXECUTE PROCEDURE authenticity.encrypt_password();

CREATE OR REPLACE FUNCTION authenticity.authenticate(credential_email text, credential_password text) 
RETURNS name AS $$

	SELECT role FROM authenticity.users 
	WHERE users.email = credential_email AND users.pass = crypt(credential_password, users.pass);

$$ LANGUAGE SQL;

/* These are the public functions exposed in our API  */

CREATE OR REPLACE FUNCTION api.signin(IN email text, IN pass text, OUT token text) AS $$
DECLARE
	_key text;
	_role name;

BEGIN
	-- check email and password
	_key := current_setting('skltn.jwt_secret');
	_role := authenticity.authenticate(email, pass);
	IF _role IS NULL THEN
		RAISE invalid_password USING MESSAGE = 'invalid user or password';
	END IF;
	WITH info AS (
		SELECT _role as role, email email, extract(epoch from now())::integer + 60*60 exp)
	SELECT sign(row_to_json(info.*), _key) FROM info INTO token;
end;
$$ language plpgsql security definer;


CREATE OR REPLACE FUNCTION api.signup(IN email text, IN pass text, OUT message json) AS $$
DECLARE
	_key text;
	_role name;
	manager boolean := false;
BEGIN

	_role := 'skltn';
	IF NOT EXISTS (SELECT 1 FROM pg_roles AS r WHERE r.rolname = _role) THEN
		EXECUTE format('CREATE ROLE %I', _role);
		manager := true;
	END IF;

	INSERT INTO authenticity.users VALUES (email, pass, _role);
	INSERT INTO authenticity.confirmation VALUES (email, substring(random()::text,3,5));
	message := json_build_object('email',email, 'organization', _role);
	
end;
$$ language plpgsql security definer;


CREATE OR REPLACE FUNCTION api.confirm(IN conf_email text, IN conf_code text, OUT message json) AS $$
DECLARE
	_key text;
	_role name;
	manager boolean := false;
BEGIN
	PERFORM * FROM authenticity.confirmation WHERE email = conf_email AND confirmation_code = conf_code;
	
	IF FOUND THEN
		UPDATE authenticity.users SET confirmed = True WHERE email = conf_email;
		message := json_build_object('email', conf_email, 'confirmed', True);
	ELSE
		RAISE invalid_password USING MESSAGE = 'Wrong confirmation code provided';
	END IF;

END;
$$ language plpgsql security definer;

GRANT USAGE ON SCHEMA api TO everyman;
GRANT USAGE ON SCHEMA api TO skltn;
GRANT USAGE ON SCHEMA authenticity TO skltn;

GRANT ALL ON TABLE authenticity.users TO skltn;

-- Adding a user based on variables from the .env file
SELECT api.signup(current_setting('skltn.api_user'), current_setting('skltn.api_password'));




