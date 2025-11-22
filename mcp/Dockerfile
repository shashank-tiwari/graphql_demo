FROM ghcr.io/apollographql/apollo-mcp-server:latest

# Copy configuration and data
COPY mcp_config.yaml /data/mcp_config.yaml
COPY data /data/data

# Expose the default port
EXPOSE 8000

# Run the Apollo MCP Server with config as argument
CMD ["mcp_config.yaml"]
