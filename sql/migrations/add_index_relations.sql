ALTER TABLE relations
  ADD KEY `from_one`(`one`, `created_at`),
  ADD KEY `from_another`(`another`, `created_at`);
