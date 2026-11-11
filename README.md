# FinpayAPI

A multi-tenant expense management REST API built with Ruby on Rails. FinpayAPI helps companies manage employee expenses, approval workflows, reimbursements, receipt records, and audit activity with tenant isolation and role-based authorization.

## Table of Contents

- [Technology Stack](#technology-stack)
- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Environment Variables](#environment-variables)
- [Running the Application](#running-the-application)
- [Demo Accounts](#demo-accounts)
- [API Documentation](#api-documentation)
- [API Endpoints](#api-endpoints)
- [Authentication](#authentication)
- [Expense Management](#expense-management)
- [Approval and Reimbursement Workflow](#approval-and-reimbursement-workflow)
- [Filtering and Pagination](#filtering-and-pagination)
- [Background Jobs](#background-jobs)
- [Testing](#testing)
- [Security](#security)
- [Project Structure](#project-structure)

## Technology Stack

| Technology | Purpose |
|---|---|
| Ruby 4.0.7 | Programming language |
| Rails 8.1.4.1 | API framework |
| PostgreSQL 18 | Relational database |
| Apartment | Schema-based multi-tenancy |
| Redis 7 | Caching and job infrastructure |
| Sidekiq | Background job processing |
| RSpec | Automated testing |
| FactoryBot | Test data factories |
| Faker | Test data generation |
| Pundit | Authorization |
| Devise | User authentication |
| AASM | Expense state management |
| Rack::Attack | API rate limiting |
| Kaminari | Pagination |
| Rswag | API documentation |
| Docker Compose | PostgreSQL and Redis services |

## Features

- Multi-tenant architecture with isolated PostgreSQL schemas for each company.
- Company registration and user authentication.
- Access-token and refresh-token authentication.
- Token revocation using a JWT denylist.
- Role-based authorization for administrators and employees.
- Expense creation, retrieval, updating, and filtering.
- Expense approval, rejection, reimbursement, and archival workflows.
- State transition validation.
- Database row locking for concurrent workflow operations.
- Idempotency protection for reimbursement requests.
- Expense activity logging and audit background jobs.
- Receipt and attachment infrastructure using Active Storage.
- Offset-based and keyset pagination.
- Redis-backed API rate limiting.
- Centralized API response and error handling.
- Automated request, model, policy, service, and worker tests.

## Architecture

FinpayAPI uses a schema-per-tenant multi-tenancy approach.

The `companies` table is maintained in the public schema. Each company receives its own PostgreSQL schema containing tenant-specific records, including users, expenses, categories, and activity logs.

Tenant identification is performed using the authenticated user's company context.

The application switches to the appropriate tenant schema when processing tenant-specific requests. This prevents records belonging to one company from being accessed through another company's tenant context.

### User roles

| Role | Permissions |
|---|---|
| Admin | View company expenses, manage approval workflows, and perform authorized administrative actions |
| Member | Create and manage their own permitted expenses |

Only administrators can approve or reject expenses. Members cannot approve their own expenses.

## Prerequisites

Install the following before setting up the application:

- Ruby 4.0.7
- Rails 8.1.4.1
- Bundler 4.0.20
- PostgreSQL 18
- Docker Desktop with Docker Compose
- Git

The development environment uses Windows with PowerShell.

PostgreSQL and Redis are provided through Docker Compose.

## Getting Started

### 1. Clone the repository

```powershell
git clone <repository-url>
cd finpay_api
```

### 2. Configure environment variables

Create your local environment file:

```powershell
Copy-Item .env.example .env
```

Update `.env` with your local PostgreSQL credentials.

Example:

```env
POSTGRES_USER=finpay_api
POSTGRES_PASSWORD=your_local_password
POSTGRES_DB=finpay_api_development
```

Do not commit `.env` or any file containing real credentials.

### 3. Install dependencies

```powershell
bundle install
```

### 4. Start infrastructure services

```powershell
docker compose up -d --wait
```

This starts:

- PostgreSQL on `localhost:5433`
- Redis on `localhost:6380`

Check service status:

```powershell
docker compose ps
```

### 5. Prepare the database

```powershell
bin/rails db:prepare
```

### 6. Create demo data

```powershell
bin/rails db:seed
```

The seed script creates two demo companies, each with an administrator, an employee, and standard expense categories. It is designed to be safe to run repeatedly.

### 7. Start the Rails server

```powershell
bin/rails server
```

The application is available at:

```text
http://localhost:3000
```

### Alternative setup

The project includes a setup script:

```powershell
ruby bin/setup
```

The script checks dependencies, starts Docker services, prepares the database, and starts the development server.

If the script has been configured to run `db:seed` during setup, demo data is created automatically. Otherwise, run `bin/rails db:seed` separately.

To prepare the application without starting the server:

```powershell
ruby bin/setup --skip-server
```

**Important:** The optional `--reset` argument resets the database. Do not use it when existing development or demo data must be preserved.

## Environment Variables

| Variable | Default / Purpose |
|---|---|
| `POSTGRES_USER` | PostgreSQL username |
| `POSTGRES_PASSWORD` | PostgreSQL password |
| `POSTGRES_DB` | PostgreSQL development database |
| `DATABASE_HOST` | Database host; defaults to `127.0.0.1` |
| `DATABASE_PORT` | Database port; defaults to `5433` |
| `FINPAY_API_DATABASE_PASSWORD` | Production database password |
| `REDIS_URL` | Redis connection URL; defaults to `redis://localhost:6380/0` outside production |
| `RAILS_MAX_THREADS` | Rails database connection pool configuration |
| `PORT` | Rails server port; defaults to `3000` |
| `EXPENSE_OVERDUE_DAYS` | Expense overdue threshold; defaults to `7` |
| `CORS_ALLOWED_ORIGINS` | Comma-separated allowed frontend origins |
| `SIDEKIQ_WEB_USERNAME` | Optional Sidekiq dashboard username |
| `SIDEKIQ_WEB_PASSWORD` | Optional Sidekiq dashboard password |
| `JOB_CONCURRENCY` | Background job process concurrency |
| `RAILS_LOG_LEVEL` | Production logging level |
| `SECRET_KEY_BASE` | Rails production secret key |

Production configuration also requires appropriate Rails credentials and database settings.

Never commit production credentials, passwords, access tokens, or secret keys.

## Running the Application

Start PostgreSQL and Redis:

```powershell
docker compose up -d
```

Start Rails:

```powershell
bin/rails server
```

Check application health:

```text
GET http://localhost:3000/up
```

Stop infrastructure services:

```powershell
docker compose stop
```

## Demo Accounts

The seed script creates the following demo accounts.

| Company | Role | Email |
|---|---|---|
| Acme Corporation | Admin | admin.acme@example.com |
| Acme Corporation | Employee | employee.acme@example.com |
| Beta Corporation | Admin | admin.beta@example.com |
| Beta Corporation | Employee | employee.beta@example.com |

**Demo password for all four accounts:**

```text
Password@123
```

These are local development credentials only. Never use them in production.

Each company has its own categories, including Meals, Travel, Office Supplies, Software, and Accommodation.

The category IDs may differ between tenants. Retrieve the category IDs from the appropriate tenant rather than assuming that the same ID exists in both schemas.

## API Documentation

The application exposes Swagger documentation through Rswag.

Once the Rails server is running, open:

```text
http://localhost:3000/api-docs
```

The API uses the following base URL:

```text
http://localhost:3000/api/v1
```

All application API endpoints are versioned under `/api/v1`.

## API Endpoints

### Authentication

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/v1/auth/register` | Register a company and its first administrator |
| POST | `/api/v1/auth/login` | Authenticate a user |
| POST | `/api/v1/auth/refresh` | Refresh authentication tokens |
| DELETE | `/api/v1/auth/logout` | Revoke the current authentication session |
| GET | `/api/v1/auth/me` | Retrieve the authenticated user's details |

### Expense management

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/v1/expenses` | List authorized expenses |
| POST | `/api/v1/expenses` | Create an expense |
| GET | `/api/v1/expenses/:id` | Retrieve an expense |
| PATCH | `/api/v1/expenses/:id` | Update an expense |
| PUT | `/api/v1/expenses/:id` | Update an expense |
| DELETE | `/api/v1/expenses/:id` | Delete an expense when permitted |

### Expense workflow

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/v1/expenses/:id/approve` | Approve an expense |
| POST | `/api/v1/expenses/:id/reject` | Reject an expense |
| POST | `/api/v1/expenses/:id/reimburse` | Reimburse an expense |
| POST | `/api/v1/expenses/:id/archive` | Archive an expense |

## Authentication

FinpayAPI uses bearer-token authentication.

### Login example

Request:

```http
POST /api/v1/auth/login
Content-Type: application/json
```

```json
{
  "company": {
    "subdomain": "acme"
  },
  "user": {
    "email": "admin.acme@example.com",
    "password": "Password@123"
  }
}
```

The response contains authentication tokens and user details.

Use the returned access token in subsequent authenticated requests:

```http
Authorization: Bearer YOUR_ACCESS_TOKEN
```

### Registration example

```http
POST /api/v1/auth/register
Content-Type: application/json
```

```json
{
  "company": {
    "name": "Demo Corporation",
    "subdomain": "demo_company"
  },
  "user": {
    "email": "admin.demo@example.com",
    "password": "Password@123",
    "password_confirmation": "Password@123"
  }
}
```

Registration creates the company and its initial administrator.

## Expense Management

Expenses store monetary values using integer minor units rather than floating-point numbers.

For example:

```json
{
  "expense": {
    "category_id": 3,
    "title": "Business Travel",
    "amount_cents": 125000,
    "currency": "INR",
    "incurred_on": "2026-11-10",
    "notes": "Travel and transportation expenses"
  }
}
```

Here, `125000` represents ₹1,250.00.

The application supports configured currencies such as INR, USD, and EUR.

Expense records also maintain workflow status, reference information, and relevant audit metadata.

## Approval and Reimbursement Workflow

Expenses follow a controlled state machine.

Supported states:

- `pending`
- `approved`
- `rejected`
- `reimbursed`
- `archived`

Workflow transitions are validated before they are executed.

The application uses database transactions and row-level locking to protect concurrent workflow operations.

Only authorized administrators can approve or reject expenses. Reimbursement is protected through idempotency handling.

### Idempotent reimbursement

Reimbursement requests support the `Idempotency-Key` header.

Example:

```http
POST /api/v1/expenses/123/reimburse
Authorization: Bearer YOUR_ACCESS_TOKEN
Idempotency-Key: reimbursement-expense-123
```

If the same request is retried with the same idempotency key and actor context, the operation is protected against duplicate processing.

## Filtering and Pagination

Expense listing supports filtering by:

- `category_id`
- `status`
- `from`
- `to`

Example:

```text
GET /api/v1/expenses?status=pending
```

### Offset pagination

```text
GET /api/v1/expenses?page=1&per=10
```

### Keyset pagination

```text
GET /api/v1/expenses?pagination=keyset&per=10
```

Pagination metadata is included in the API response.

## Background Jobs

FinpayAPI uses Sidekiq and Redis for background processing.

Background processing supports audit-related jobs and other asynchronous application operations.

Sidekiq Web is mounted at:

```text
http://localhost:3000/sidekiq
```

The dashboard is protected by HTTP Basic Authentication. Configure its credentials through environment variables or Rails credentials before accessing it.

The application schedules workflow audit jobs after database transactions commit, helping prevent workers from processing records before their transactions are committed.

## Testing

The project uses RSpec for automated testing.

Run the complete test suite:

```powershell
bundle exec rspec
```

Run individual spec directories:

```powershell
bundle exec rspec spec/models
bundle exec rspec spec/requests
bundle exec rspec spec/services
bundle exec rspec spec/policies
bundle exec rspec spec/workers
```

Run RuboCop:

```powershell
bundle exec rubocop
```

Automatically correct safe style offenses:

```powershell
bundle exec rubocop -A
```

Run Brakeman security analysis:

```powershell
bundle exec brakeman
```

Check dependencies for known security vulnerabilities:

```powershell
bundle exec bundler-audit check --update
```

Check installed dependencies:

```powershell
bundle check
```

### Latest verification results

The following results were recorded during project verification:

| Check | Result |
|---|---|
| RSpec | 283 examples, 0 failures |
| Line coverage | 92.39% |
| Branch coverage | 84.06% |
| RuboCop | 159 files inspected, no offenses |
| Brakeman | 0 security warnings |
| Bundler Audit | No vulnerabilities found |

These are the results from the recorded verification run; rerun the commands after making code changes.

## Security

Security measures implemented in the application include:

- Schema-based tenant isolation.
- Bearer-token authentication.
- Token revocation through a JWT denylist.
- Pundit-based authorization.
- Role-based workflow restrictions.
- Strong parameter handling.
- Database constraints and foreign keys.
- Encrypted sensitive expense fields.
- Row-level locking for workflow operations.
- Idempotency protection for reimbursements.
- Redis-backed rate limiting.
- Protected Sidekiq Web dashboard.
- Centralized API error handling.

Login rate limits are configured by IP address and email address. Authenticated API requests are also subject to token-based throttling.

## Project Structure

```text
finpay_api/
│
├── app/
│   ├── controllers/
│   │   └── api/
│   │       └── v1/
│   ├── jobs/
│   ├── lib/
│   ├── mailers/
│   ├── models/
│   ├── policies/
│   ├── presenters/
│   ├── serializers/
│   ├── services/
│   ├── views/
│   └── workers/
│
├── bin/
│   └── setup
│
├── config/
│   ├── environments/
│   ├── initializers/
│   ├── database.yml
│   ├── routes.rb
│   └── application.rb
│
├── db/
│   ├── migrate/
│   ├── seeds.rb
│   └── schema.rb
│
├── spec/
│   ├── factories/
│   ├── initializers/
│   ├── models/
│   ├── policies/
│   ├── requests/
│   ├── services/
│   ├── support/
│   └── workers/
│
├── compose.yaml
├── Dockerfile
├── Gemfile
├── Gemfile.lock
└── README.md
```

### Important application directories

| Directory | Responsibility |
|---|---|
| `controllers` | Handle HTTP requests and responses |
| `models` | Define database records, associations, and validations |
| `policies` | Enforce authorization rules |
| `services` | Handle business logic and workflows |
| `serializers` | Format API response data |
| `presenters` | Prepare data for presentation |
| `workers` | Execute asynchronous background jobs |
| `jobs` | Define application background jobs |
| `spec` | Automated test coverage |
| `config/initializers` | Configure application dependencies and middleware |
| `db/migrate` | Database schema migrations |

## Development Notes

- Keep all tenant-specific operations within the correct tenant context.
- Do not expose one company's records to another company.
- Store money as integer minor units and never use floating-point values for financial calculations.
- Keep workflow transitions inside the workflow service.
- Preserve audit records rather than deleting historical activity.
- Use idempotency keys for operations that must not be duplicated.
- Never commit `.env`, credentials, access tokens, or other secrets.

---

**FinpayAPI — Multi-Tenant Expense Management API**