# Jira adapter

Config: `tracker: { type: jira, jira: { site: yourco.atlassian.net, project: ABC }, states: {...} }`

## Access

Prefer the Atlassian MCP tools (Atlassian Rovo MCP server or a connected Atlassian connector): `getJiraIssue`, `searchJiraIssuesUsingJql`, `addCommentToJiraIssue`, `getTransitionsForJiraIssue`, `transitionJiraIssue`, `createJiraIssue`, `getAccessibleAtlassianResources`, with a server prefix. Not loaded -> search for them (ToolSearch "jira").

No Atlassian MCP tools in the session -> tell the user the project's `.mcp.json` should declare the Atlassian server (see the singularity `templates/mcp/jira.mcp.json`) and each person authenticates once with `/mcp`. Fallback: the Atlassian CLI `acli`, only if installed and authenticated (exact syntax: `acli jira workitem --help`).

Most tools need the cloud ID: call `getAccessibleAtlassianResources` once; pick the resource whose URL matches `jira.site`.

## Operations

- **get**: `getJiraIssue` with the key. Acceptance criteria: often under a description heading like "Acceptance criteria", or in a custom field; report both if present. Include issue type and linked issues.
- **comment**: `addCommentToJiraIssue`. Plain, short text with the PR/MR link.
- **move**: call `getTransitionsForJiraIssue`, pick the transition whose target status equals `tracker.states[<state>]`, then `transitionJiraIssue`. None matches -> report the available ones; don't guess.
- **link**: comment with the PR/MR URL. Code host has the Jira integration -> also put the key (`ABC-123`) in the branch name and PR/MR title (links automatically).
- **create**: `createJiraIssue` in `jira.project` (only on explicit request).
