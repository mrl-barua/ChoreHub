-- CreateIndex
CREATE INDEX "chore_history_family_id_action_created_at_idx" ON "chore_history"("family_id", "action", "created_at");
