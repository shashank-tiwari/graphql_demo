# graphql_demo

Apollo GraphQL server using in-memory mock data and exposing an `agents` query.

Setup

1. (Optional) Copy `.env.example` to `.env` if you want to set environment variables:

```powershell
copy .env.example .env
notepad .env
```

2. Install dependencies:

```powershell
npm install
```

3. Start the server in development mode:

```powershell
npm run dev
```

Or start normally:

```powershell
npm start
```

GraphQL query example

Use the GraphQL playground (server URL printed on start) or any GraphQL client and run:

```graphql
query {
  agents {
    firstname
    lastname
    contactnumber
  }
}
  agents {
    id
    firstname
    lastname
    contactnumber
    customers {
      id
      firstname
      lastname
      contactnumber
    }
  }
}

# Point queries and listing queries

# Get a single agent by id (point query)
query {
  agent(id: "1") {
    id
    firstname
    lastname
    contactnumber
    customers {
      id
      firstname
    }
  }
}

# Get a single customer by id (point query)
query {
  customer(id: "c1") {
    id
    firstname
    lastname
    contactnumber
    agent {
      id
      firstname
    }
  }
}
```

Notes
- The server uses in-memory mock data (no external DB required). Data resets when the process restarts.

## Azure Functions Local Testing

Test the Azure Functions deployment locally before deploying to Azure:

```powershell
func start
```

GraphQL endpoint: `http://localhost:7071/api/graphql`

## Deploy to Azure

### Prerequisites

- Azure CLI installed (`az --version`)
- Azure subscription
- Logged in to Azure: `az login`

### Deployment Steps

1. **Create Resource Group** (if not exists):
```powershell
az group create --name graphql-demo-rg --location eastus
```

2. **Create Storage Account**:
```powershell
az storage account create `
  --name graphqldemo<random> `
  --resource-group graphql-demo-rg `
  --location eastus `
  --sku Standard_LRS
```

3. **Create Function App**:
```powershell
az functionapp create `
  --resource-group graphql-demo-rg `
  --consumption-plan-location eastus `
  --runtime node `
  --runtime-version 18 `
  --functions-version 4 `
  --name graphql-demo-app `
  --storage-account graphqldemo<random>
```

4. **Deploy Function**:
```powershell
cd c:\Users\shash\git_repos\graphql_demo
func azure functionapp publish graphql-demo-app
```

5. **Access GraphQL Endpoint**:
After deployment, your GraphQL endpoint will be:
```
https://graphql-demo-app.azurewebsites.net/api/graphql
```

### View Logs

```powershell
func azure functionapp logstream graphql-demo-app
```
