# Content Marketing Swarm

A multi-agent system for automated content generation, optimization, and scheduling across social media platforms.

## Project Structure

```
.
├── backend/                 # FastAPI backend
│   ├── app/
│   │   ├── agents/         # Strands agent implementations
│   │   ├── tools/          # Agent tools
│   │   ├── models/         # Database models
│   │   ├── repositories/   # Data access layer
│   │   └── api/            # API endpoints
│   ├── migrations/         # Alembic database migrations
│   └── tests/              # Backend tests
├── frontend/               # Next.js frontend
│   ├── app/                # Next.js app directory
│   ├── components/         # React components
│   └── lib/                # Utility functions
└── infrastructure/         # Terraform infrastructure
    └── terraform/
        ├── modules/        # Reusable Terraform modules
        └── environments/   # Environment-specific configs
```

## Setup

### Backend

1. Create and activate virtual environment:
```bash
cd backend
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Run database migrations:
```bash
alembic upgrade head
```

5. Start the backend server:
```bash
uvicorn app.main:app --reload
```

### Frontend

1. Install dependencies:
```bash
cd frontend
npm install
```

2. Configure environment variables:
```bash
cp .env.local.example .env.local
# Edit .env.local with your configuration
```

3. Start the development server:
```bash
npm run dev
```

### Infrastructure

1. Initialize Terraform:
```bash
cd infrastructure/terraform/environments/dev
terraform init
```

2. Plan infrastructure changes:
```bash
terraform plan
```

3. Apply infrastructure:
```bash
terraform apply
```

## Architecture

The system uses a Swarm pattern with three specialized agents:

- **Research Agent**: Analyzes trends, competitors, and audience insights
- **Creator Agent**: Generates platform-specific content and visual assets
- **Scheduler Agent**: Optimizes posting times and manages content calendar

## Technologies

- **Backend**: FastAPI, Strands Agents, SQLAlchemy, PostgreSQL
- **Frontend**: Next.js, React, TypeScript, Tailwind CSS
- **Infrastructure**: Terraform, AWS (ECS, RDS, S3, CloudFront, ACM)
- **AI**: Amazon Bedrock (Claude Sonnet 4.5, Amazon Nova)
- **Security**: HTTPS/TLS via AWS Certificate Manager, WSS for WebSocket

## Documentation

### Deployment & Operations
- **[Deployment Guide](DEPLOYMENT_GUIDE.md)** - Complete production deployment instructions
- **[Quick Deployment Reference](QUICK_DEPLOYMENT_REFERENCE.md)** - Quick reference for common deployment tasks
- **[Infrastructure README](infrastructure/terraform/README.md)** - Terraform infrastructure documentation

### HTTPS Configuration
- **[HTTPS Troubleshooting Guide](HTTPS_TROUBLESHOOTING_GUIDE.md)** - Comprehensive HTTPS troubleshooting
- **[Environment Variables Guide](ENVIRONMENT_VARIABLES_GUIDE.md)** - Environment variable configuration
- **[HTTPS Setup Spec](.kiro/specs/https-alb-setup/)** - Detailed HTTPS setup specification

### Additional Resources
- **[AWS Infrastructure Setup](AWS_INFRASTRUCTURE_SETUP.md)** - AWS infrastructure overview
- **[Knowledge Base Integration](backend/KB_INTEGRATION_GUIDE.md)** - Bedrock Knowledge Base setup
- **[AgentCore Deployment](backend/AGENTCORE_DEPLOYMENT.md)** - AgentCore Runtime deployment

## Security

The application implements comprehensive security measures:

- **HTTPS/TLS**: All production traffic encrypted via AWS Certificate Manager
- **WebSocket Security**: WSS protocol for real-time streaming
- **Network Isolation**: Private subnets for backend services
- **Data Encryption**: Encryption at rest for RDS and S3
- **IAM Policies**: Least-privilege access control
- **Security Groups**: Restrictive firewall rules

For HTTPS configuration and troubleshooting, see:
- [HTTPS Troubleshooting Guide](HTTPS_TROUBLESHOOTING_GUIDE.md)
- [Environment Variables Guide](ENVIRONMENT_VARIABLES_GUIDE.md)

## License

MIT
