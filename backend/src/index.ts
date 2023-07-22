import "dotenv/config"
import mysql from "mysql2/promise";
import express from "express";

import ScoreApi from "./api/scores";
import ErrorHandler from "./errors";

const app = express();

const start = async () => {
	const connection = mysql.createPool({
		host: "127.0.0.1",
		user: "db",
		database: "dbrank",
		connectionLimit: 2,
	});

	app.use("/", ScoreApi);
	app.use(ErrorHandler);

	app.set("db", connection);
	
	app.listen(process.env.PORT)
}

start();