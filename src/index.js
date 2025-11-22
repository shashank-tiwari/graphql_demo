require('dotenv').config();
const { ApolloServer } = require('@apollo/server');
const { v4 } = require('@as-integrations/azure-functions');
const typeDefs = require('./schema');
const resolvers = require('./resolvers');

// In-memory mock data to replace SQLite
const mockData = {
  agents: [
    { id: '1', firstname: 'Jane', lastname: 'Doe', contactnumber: '555-0101' },
    { id: '2', firstname: 'John', lastname: 'Smith', contactnumber: '555-0202' }
  ],
  customers: [
    { id: 'c1', firstname: 'Alice', lastname: 'Brown', contactnumber: '555-1001', agentId: '1' },
    { id: 'c2', firstname: 'Bob', lastname: 'Green', contactnumber: '555-1002', agentId: '1' },
    { id: 'c3', firstname: 'Charlie', lastname: 'Black', contactnumber: '555-1003', agentId: '2' }
  ]
};

const server = new ApolloServer({
  typeDefs,
  resolvers
});

const innerHandler = v4.startServerAndCreateHandler(server, {
  // The integration expects an option named `context` (it will call it with
  // an object `{ context, req }`). Return an object that includes `data`.
  context: async (ctx) => ({ data: mockData, context: ctx.context })
});

module.exports = async function (context, req) {
  if (!context.error) {
    context.error = (...args) => {
      if (context.log && typeof context.log.error === 'function') {
        return context.log.error(...args);
      }
      // Fallback to console.error if log.error isn't available
      return console.error(...args);
    };
  }

  // Ensure `req.headers` implements `get()` and `entries()` (like a Map/Headers)
  if (req && req.headers && (typeof req.headers.get !== 'function' || typeof req.headers.entries !== 'function')) {
    const raw = req.headers || {};
    const entries = Object.entries(raw).map(([k, v]) => [k, Array.isArray(v) ? v.join(',') : String(v)]);
    req = { ...req, headers: new Map(entries) };
  }

  // Provide a `json()` method if missing (Azure Functions HttpRequest may provide body/rawBody)
  if (!req.json || typeof req.json !== 'function') {
    req.json = async () => {
      if (req.body !== undefined && req.body !== null) {
        return req.body;
      }
      if (req.rawBody) {
        try {
          if (typeof req.rawBody === 'string') {
            return JSON.parse(req.rawBody);
          }
          return JSON.parse(req.rawBody.toString());
        }
        catch (e) {
          return null;
        }
      }
      return null;
    };
  }

  return innerHandler(req, context);
};
