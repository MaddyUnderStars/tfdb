// Stolen from another project of mine teehee

import { RequestHandler } from "express";
import { Runtype } from "runtypes";

interface RouteOptions<Body, Params, Response, Query> {
	body?: Runtype<Body>;
	params?: Runtype<Params>;
	query?: Runtype<Query>;
	response: Runtype<Response>;
}

export const Route = <Body, Params, Response, Query>(
	opts: RouteOptions<Body, Params, Response, Query>,
	handler: RequestHandler<Params, Response, Body, Query>,
) => {
	const routeHandler: RequestHandler = async (req, res, next) => {
		try {
			// throw exceptions if inputs are wrong
			// handled in error handler middleware
			if (req.body && opts.body) opts.body.check(req.body);
			if (req.params && opts.params) opts.params.check(req.params);
			if (req.query && opts.query) opts.query.check(req.query);

			// @ts-ignore TODO: I'll figure this out later :p
			return await handler.call(this, req, res, next);
		} catch (e) {
			next(e);
		}
	};

	return routeHandler;
};
