ALTER TABLE users ADD COLUMN `salt` varchar(6) AFTER `passhash` DEFAULT NULL;
UPDATE users SET salt = (SELECT salt FROM salts WHERE users.id = salts.user_id);
