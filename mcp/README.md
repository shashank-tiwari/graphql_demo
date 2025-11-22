# Apollo MCP Server Setup

This directory contains the Apollo Model Context Protocol (MCP) Server configuration for testing your GraphQL API.

## Structure

```
mcp/
├── mcp_config.yaml          # Apollo MCP Server configuration
├── docker-compose.yml       # Docker Compose setup
├── Dockerfile              # Docker image definition
└── data/
    ├── api.graphql         # GraphQL schema
    └── operations/         # GraphQL operations/queries
```

## Configuration

The `mcp_config.yaml` configures:
- **Endpoint**: Points to your Azure Function GraphQL API
- **Schema**: Local schema file reference
- **Operations**: Directory containing GraphQL queries
- **Transport**: HTTP transport with stateless mode

## Running with Docker

### Option 1: Using docker-compose (Recommended)

```powershell
# Start the server
cd mcp
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the server
docker-compose down
```

### Option 2: Using Docker directly

```powershell
# From the mcp directory
docker run -it --rm --name apollo-mcp-server `
  -p 8000:8000 `
  -v "${PWD}/mcp_config.yaml:/config.yaml:ro" `
  -v "${PWD}/data:/data:ro" `
  ghcr.io/apollographql/apollo-mcp-server:latest /config.yaml
```

### Option 3: Building custom image

```powershell
# Build the image
docker build -t apollo-mcp-local .

# Run the container
docker run -it --rm -p 8000:8000 apollo-mcp-local
```

## Testing

Once running, the Apollo MCP Server will be available at:
- **MCP Server**: http://localhost:8000

You can interact with it using MCP-compatible clients or tools.

## Operations

Sample operations are available in `data/operations/`:
- `GetAllAgents.graphql` - Retrieve all agents
- `GetAllCustomers.graphql` - Retrieve all customers with their agents
- `GetAgentById.graphql` - Retrieve a specific agent by ID

## Troubleshooting

1. **Port already in use**: Change the port mapping in docker-compose.yml
2. **Volume mount issues**: Ensure paths are correct for your OS
3. **Schema not found**: Verify the schema path in mcp_config.yaml matches the actual file location
4. **Connection refused**: Check that your Azure Function endpoint is accessible

## Configuration Details

The server uses:
- **Stateless mode**: For easy testing without session management
- **Streamable HTTP transport**: For efficient data streaming
- **Local schema**: Schema is loaded from the local file system
- **Local operations**: Operations are loaded from the operations directory
