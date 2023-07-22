import { Router } from "express";
import { Route } from "../lib";
import { Connection } from "mysql2/promise";
import { ScoresQuery, ScoresResponse, Score } from "./scores.types";
import { Static } from "runtypes";

const router = Router();

let badwords: string[] = [];

router.get("scores", Route({ query: ScoresQuery, response: ScoresResponse }, async (req, res) => {
	if (!badwords.length) {
		badwords = await fetch("https://raw.githubusercontent.com/zacanger/profane-words/master/words.json")
		.then(x => x.json()) as string[];
	}
	
	const offset = parseInt(req.query.offset ?? "0");

	const db = req.app.get("db") as Connection;
	
	const out = await db.execute("SELECT name, rating, kills, deaths FROM elostats ORDER BY rating DESC LIMIT ?, 10", [offset]);
	const rows = (out[0] as Static<typeof Score>[]).map(score => {
		badwords.forEach(bad => score.name = score.name.replaceAll(bad, "*".repeat(bad.length)));
		return score;
	});

	return res.json({
		scores: rows
	})
}));

export default router;