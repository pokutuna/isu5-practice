ALTER TABLE comments
  ADD COLUMN `entry_author_id` int NOT NULL AFTER `user_id`;
ALTER TABLE comments
  ADD KEY eaid_created_at(`entry_author_id`, `created_at`);

UPDATE comments
  SET entry_author_id = (
    SELECT user_id FROM entries WHERE entries.id = comments.entry_id
  );
