const resolvers = {
  Query: {
    agents: async (_, __, { data }) => {
      return data.agents;
    },
    customers: async (_, __, { data }) => {
      return data.customers;
    },
    agent: async (_, { id }, { data }) => {
      return data.agents.find(a => a.id === id) || null;
    },
    customer: async (_, { id }, { data }) => {
      return data.customers.find(c => c.id === id) || null;
    }
  },

  Agent: {
    customers: (agent, _, { data }) => {
      return data.customers.filter(c => c.agentId === agent.id);
    }
  },

  Customer: {
    agent: (customer, _, { data }) => {
      return data.agents.find(a => a.id === customer.agentId) || null;
    }
  }
};

module.exports = resolvers;
