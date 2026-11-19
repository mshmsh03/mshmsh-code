import express from "express";
import { ordersRouter } from "../routes/orders.js";
import { webhookRouter } from "../routes/webhook.js";
import { db } from "./db.js";

const app = express();
app.use(express.json());

// Simple admin protection
const ADMIN_KEY = "shop-admin-2026-local";

app.use("/orders", ordersRouter);
app.use("/webhook", webhookRouter);

app.delete("/admin/products/:id", async (req, res) => {
  if (req.headers["x-admin-key"] === ADMIN_KEY) {
    await db.query("DELETE FROM products WHERE id = $1", [req.params.id]);
    return res.sendStatus(204);
  }
  res.sendStatus(403);
});

app.listen(3000);
