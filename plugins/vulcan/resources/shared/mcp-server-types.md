# MCP Server Types & Configuration

MCP (Model Context Protocol) servers extend Copilot with external tools. They run as separate processes and expose tools that Copilot can invoke during conversations.

## Server Types

| Type            | Description                               | Use Case                              |
|-----------------|-------------------------------------------|---------------------------------------|
| **Local/Stdio** | Subprocess, communicates via stdin/stdout  | Local tools, file access, scripts     |
| **HTTP/SSE**    | Remote server accessed via HTTP            | Shared services, cloud-hosted tools   |

## Local/Stdio Server Options

| Property  | Type       | Required | Description                                |
|-----------|------------|----------|--------------------------------------------|
| `type`    | `"local"`  | No       | Server type (defaults to local)            |
| `command` | `string`   | Yes      | Command to execute                         |
| `args`    | `string[]` | Yes      | Command arguments                          |
| `env`     | `object`   | No       | Environment variables                      |
| `cwd`     | `string`   | No       | Working directory                          |
| `tools`   | `string[]` | No       | Tools to enable (`["*"]` all, `[]` none)   |
| `timeout` | `number`   | No       | Timeout in milliseconds                    |

## Remote Server Options (HTTP/SSE)

| Property  | Type       | Required | Description                      |
|-----------|------------|----------|----------------------------------|
| `type`    | `"http"`   | Yes      | Server type                      |
| `url`     | `string`   | Yes      | Server URL                       |
| `headers` | `object`   | No       | HTTP headers (e.g., auth)        |
| `tools`   | `string[]` | No       | Tools to enable                  |
| `timeout` | `number`   | No       | Timeout in milliseconds          |

> **v1.0.25:** Remote MCP server connections automatically retry on transient network failures. The MCP client also reports the correct CLI version during server handshake.

## Popular MCP Servers

From the [MCP Servers Directory](https://github.com/modelcontextprotocol/servers):

| Package                                        | Purpose              |
|------------------------------------------------|----------------------|
| `@modelcontextprotocol/server-filesystem`      | File system access   |
| `@modelcontextprotocol/server-github`          | GitHub API access    |
| `@modelcontextprotocol/server-sqlite`          | SQLite database      |
| `@modelcontextprotocol/server-postgres`        | PostgreSQL access    |
| `@modelcontextprotocol/server-puppeteer`       | Browser automation   |
| `@microsoft/mcp-server-playwright`             | Playwright testing   |

## Troubleshooting

| Issue                       | Solution                                              |
|-----------------------------|-------------------------------------------------------|
| Tools not showing up        | Verify `tools` is `["*"]` or lists specific tools     |
| MCP server not found        | Check command path is correct and executable          |
| Connection refused (HTTP)   | Verify URL and server is running                      |
| Timeout errors              | Increase `timeout` value                              |
| Tools not being invoked     | Make prompt clearly require the tool's functionality  |
