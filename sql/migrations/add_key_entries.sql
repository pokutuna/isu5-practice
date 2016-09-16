ALTER TABLE entries ADD KEY `user_id_private` (`user_id`, `is_private`);
alter table footprints add key user_id_created_at(user_id, created_at);
