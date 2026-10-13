# Jira adapter

Config: `tracker: { type: jira, jira: { site: yourco.atlassian.net, project: ABC }, states: {...} }`

## Access

Prefer the Atlassian MCP tools (Atlassian Rovo MCP server or a connected Atlassian connector). Their names look like `getJiraIssue`, `searchJiraIssuesUsingJql`, `addCommentToJiraIssue`, `getTransitionsForJiraIssue`, `transitionJiraIssue`, `createJiraIssue`, `getAccessibleAtlassianResources`, with a server prefix. If they are not loaded, search for them (ToolSearch "jira").

If no Atlassian MCP tools exist in the session, tell the user the project's `.mcp.json` should declare the Atlassian server (see the singularity `templates/mcp/jira.mcp.json`) and that each person authenticates once with `/mcp`. Fall back to the Atlassian CLI `acli` only if it is installed and authenticated (check `acli jira workitem --help` for the exact syntax).

Most tools need the cloud ID: call `getAccessibleAtlassianResources` once and pick the resource whose URL matches `jira.site`.

## Operations

- **get**: `getJiraIssue` with the key. Acceptance criteria are often in the description under a heading like "Acceptance criteria", or in a custom field; report both if present. Include issue type and linked issues.
- **comment**: `addCommentToJiraIssue`. Plain, short text with the PR/MR link.
- **move**: call `getTransitionsForJiraIssue`, pick the transition whose target status equals `tracker.states[<state>]`, then `transitionJiraIssue`. If no transition matches, report the available ones instead of guessing.
- **link**: comment with the PR/MR URL. If the code host has the Jira integration, putting the key (`ABC-123`) in the branch name and PR/MR title links it automatically, so do that.
- **create**: `createJiraIssue` in `jira.project` (only on explicit request).
