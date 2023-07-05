this repo contains my tfdb server configs.
currently, that is just a 3r server hosted at tfdb.understars.dev.

you'll find the server cfg and sourcemod plugin configs here including the dodgeball config,
as well as a full list of plugins with links

the server setup is probably reasonably standard
- fastdl at tfdb.understars.dev/fastdl using nginx
- - this just exposes the ~/fastdl folder with `maps`, `materials`, `models` online, and these folders are simlinked into the tf directory
- otherwise the setup is basically just a no thoughts required walk through of the sourcemod guide