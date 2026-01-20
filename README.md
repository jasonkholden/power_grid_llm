power_grid_llm is a website chatbot to help you decide when to do electrity-intensive tasks (where you have some amount of latitude on the "when" you do it) to minimize your carbon footprint.  The canonical example is doing laundry (in my house, this is by far the largest use of electricity).

Goals:
 - Educate about the grid mix (gas/solar/wind) and how it varies by day and by time and time of year
 - Do a little good (if its a cold and cloudy friday, and tomorrow is a sunny saturday, waiting till tomorrow will likely have a better power mix of solar/wind/nuclear)
 - Build some cool tech for further iteration in this space

There's a start to an MCP server for the New England Power Grid i've written at https://github.com/jasonkholden/ne_power_grid_mcp_server that should power our queries to the power grid


Implimentation Plan
- Tech stack: react frontend, fastapi backend, fastmcp for our mcp server, sqllite as db (for now), terraform infra-as-code targeting AWS where minimizing cost is primary metric, LLM claude.ai using API connectivity
- external dependency: ../ne_power_grid_mcp_server (MCP server for the NE power grid that I am a maintainer for; we will extend this as needed)
- website DNS name (TBD, use foobar.com for now)
- local development: docker containers using docker-compose
- prod deployment: docker containers to EC2 instance, ssl via certbot

Website Spec
- Front Page
  - Pie chart of current power mix
  - line chart of power mix since midnight of previous day (including predicted amount of residential solar)
  - line char of predicted power mix through midnight of following day
  - read-only text box to chat on when is the best time to do laundry (pre-canned prompts, not dealing with prompt injection right now)
  - user login and registration workflow, including /admin role for user approval (Out of scope for the moment)
  - button for use to click "I'm doing laundry now" or "I'm planning on doing laundry at a predicted time
  - slider on predicted power mix chart that updates a carbon saved / extra carbon used calculation
- Backend
  - 5 minute time-to-live caching on API requests to raw external power grid api endpoints (so we don't overuse our external API quota) and any AI-enabled endpoints (to save $) 