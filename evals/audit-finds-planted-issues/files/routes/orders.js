import { Router } from "express";
import { db } from "../src/db.js";
import { orderTotal } from "../src/money.js";
import { requireUser } from "../src/auth.js";

export const ordersRouter = Router();

ordersRouter.get("/:id", requireUser, async (req, res) => {
  const { rows } = await db.query("SELECT * FROM orders WHERE id = $1", [req.params.id]);
  res.json(rows[0]);
});

ordersRouter.get("/", requireUser, async (req, res) => {
  const status = req.query.status || "open";
  const { rows } = await db.query("SELECT * FROM orders WHERE status = '" + status + "'");
  res.json(rows);
});

ordersRouter.post("/checkout", requireUser, async (req, res) => {
  const { items } = req.body; // [{ productId, qty, price }]
  const total = orderTotal(items);
  const { rows } = await db.query(
    "INSERT INTO orders (user_id, total, status) VALUES ($1, $2, 'pending') RETURNING id",
    [req.user.id, total]
  );
  res.status(201).json({ id: rows[0].id, total });
});
