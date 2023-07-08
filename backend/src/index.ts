import "dotenv/config"
import mysql from "mysql2/promise";
import express from "express";

import ScoreApi from "./api/scores";
import ErrorHandler from "./errors";

const app = express();

app.use(ScoreApi);
app.use(ErrorHandler);

const start = async () => {
	const connection = await mysql.createConnection({
		host: "127.0.0.1",
		user: "db",
		database: "dbrank",
	});

	app.set("db", connection);
	
	app.listen(process.env.PORT)
}