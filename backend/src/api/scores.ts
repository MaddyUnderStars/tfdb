import { Router } from "express";
import { Route } from "../lib";
import { Connection } from "mysql2/promise";
import { ScoresQuery, ScoresResponse } from "./scores.types";

const router = Router();

router.get("/scores", Route({ query: ScoresQuery, response: ScoresResponse }, async (req, res) => {
	const offset = parseInt(req.query.offset ?? "0");

	const db = req.app.get("db") as Connection;
	
	const [rows, _] = await db.execute("SELECT name, rating, kills, deaths FROM elostats ORDER BY rating LIMIT ?, 10", [offset]);

	return res.json({
		//@ts-ignore don't care rn
		scores: [rows]
	})
}));

export default router;