-- ============================================================
-- Hatch2Revenue — Role-based access control, Stage 2
--
-- Lets WORKERS record egg sales. A worker's sale posts:
--   * an egg_sales row (the sale + any balance owed), and
--   * an income financial transaction (so the sale reaches the books).
-- Workers still cannot SEE the debtors ledger, totals, or profit, and
-- cannot edit or delete anything. The financial-transaction insert is
-- restricted to income rows (type = 0) so a worker cannot fabricate an
-- expense to mask cash they took.
--
-- Run this AFTER h2r_roles_schema.sql. Idempotent (drops first).
-- ============================================================

-- Workers may record sales into the ledger.
drop policy if exists "sales insert" on h2r_egg_sales;
create policy "sales insert" on h2r_egg_sales for insert with check (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and user_id = auth.uid() and h2r_can_log(farm_id)));

-- Owner/manager may post any financial transaction; a worker may post
-- ONLY income (type 0), which is the egg-sale income line. They still
-- cannot select, update or delete financial transactions.
-- NOTE: "type" = 0 corresponds to TransactionType.income in the app.
drop policy if exists "fin insert" on h2r_financial_transactions;
create policy "fin insert" on h2r_financial_transactions for insert with check (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and user_id = auth.uid() and h2r_can_amend(farm_id))
  or (farm_id is not null and user_id = auth.uid() and h2r_can_log(farm_id) and "type" = 0));
