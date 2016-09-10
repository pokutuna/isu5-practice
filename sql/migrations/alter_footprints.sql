DROP TABLE IF EXISTS footprints;
CREATE TABLE footprints (
  `id` int NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `user_id` int NOT NULL, -- あしあとをつけられた人
  `owner_id` int NOT NULL, -- 足跡のヌシ
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `user_id_owner_id` (`user_id`, `owner_id`) -- new!!
) DEFAULT CHARSET=utf8;
