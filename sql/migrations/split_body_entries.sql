DROP TABLE IF EXISTS entries;
CREATE TABLE IF NOT EXISTS entries (
  `id` int NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `user_id` int NOT NULL,
  `is_private` tinyint NOT NULL,
  `title` text,
  `content` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY `user_id` (`user_id`,`created_at`),
  KEY `created_at` (`created_at`)
) DEFAULT CHARSET=utf8mb4;
