module.exports = `
  type Agent {
    id: ID
    firstname: String
    lastname: String
    contactnumber: String
    customers: [Customer]
  }

  type Customer {
    id: ID
    firstname: String
    lastname: String
    contactnumber: String
    agent: Agent
  }

  type Query {
    agents: [Agent]
    customers: [Customer]
    agent(id: ID!): Agent
    customer(id: ID!): Customer
  }
`;
