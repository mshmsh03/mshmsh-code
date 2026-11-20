import { Router } from "express";
import { db } from "../src/db.js";

export const webhookRouter = Router();

webhookRouter.post("/payment", async (req, res) => {
  const event = req.body;
  if (event.type === "payment.succeeded") {
    await db.query("UPDATE orders SET status = 'paid' WHERE id = $1", [event.data.orderId]);
  }
  res.sendStatus(200);
});
