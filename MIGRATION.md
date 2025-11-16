# Bike Marketplace Migration Guide

## Overview

This document describes the migration from Ruby on Rails + Stimulus.js to React/Next.js + Python/FastAPI.

## Technology Stack Changes

### Frontend
- **Before:** HAML templates, Stimulus.js, Turbo Rails
- **After:** React, Next.js 15, TypeScript, Tailwind CSS

### Backend
- **Before:** Ruby on Rails, Grape API, Sidekiq
- **After:** Python, FastAPI, SQLAlchemy, Celery (planned)

### Database
- **Unchanged:** PostgreSQL

## Project Structure

```
bike_marketplace/
├── frontend/              # Next.js application
│   ├── app/              # Next.js app directory
│   ├── components/       # React components
│   │   ├── auth/         # Authentication components
│   │   ├── bikes/        # Bike-related components
│   │   └── marketplace/  # Marketplace components
│   ├── lib/              # Utility functions and API client
│   └── public/           # Static assets
│
├── backend/              # FastAPI application
│   ├── app/
│   │   ├── models/       # SQLAlchemy models
│   │   ├── routes/       # API endpoints
│   │   ├── schemas/      # Pydantic schemas
│   │   ├── services/     # Business logic
│   │   ├── config.py     # Configuration
│   │   ├── database.py   # Database setup
│   │   └── main.py       # FastAPI app
│   ├── requirements.txt  # Python dependencies
│   └── .env.example      # Environment variables template
│
└── docker-compose.yml    # Docker orchestration
```

## Migrated Features

### Phase 1: Core Infrastructure ✅
- Next.js frontend with TypeScript and Tailwind CSS
- FastAPI backend with project structure
- PostgreSQL database models with SQLAlchemy

### Phase 2: Core Models ✅
- User model with authentication
- Bike model with specifications
- Organization model
- Manufacturer and Color models
- StolenRecord model
- MarketplaceListing model

### Phase 3: Authentication ✅
- JWT-based authentication
- OAuth2 password flow
- User registration and login
- Password hashing with bcrypt

### Phase 4: API Endpoints ✅
- `/api/v1/auth/*` - Authentication endpoints
- `/api/v1/users/*` - User management
- `/api/v1/bikes/*` - Bike registration and search
- `/api/v1/marketplace/*` - Marketplace listings

### Phase 5: Frontend Components ✅
- Login form
- Bike registration form
- Marketplace listing form
- API client library

## Running the Application

### Using Docker Compose (Recommended)

1. Start all services:
   ```bash
   docker-compose up -d
   ```

2. Access the application:
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:8000
   - API Documentation: http://localhost:8000/docs

### Manual Setup

#### Backend

1. Create a virtual environment:
   ```bash
   cd backend
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Set up environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. Run the server:
   ```bash
   uvicorn app.main:app --reload
   ```

#### Frontend

1. Install dependencies:
   ```bash
   cd frontend
   npm install
   ```

2. Set up environment variables:
   ```bash
   echo "NEXT_PUBLIC_API_URL=http://localhost:8000" > .env.local
   ```

3. Run the development server:
   ```bash
   npm run dev
   ```

## Database Setup

### Using Alembic (Recommended for production)

1. Initialize Alembic:
   ```bash
   cd backend
   alembic init alembic
   ```

2. Create migration:
   ```bash
   alembic revision --autogenerate -m "Initial migration"
   ```

3. Apply migration:
   ```bash
   alembic upgrade head
   ```

### Using SQLAlchemy (Quick setup)

```python
from app.database import engine, Base
from app.models import user, bike, organization  # Import all models

# Create all tables
Base.metadata.create_all(bind=engine)
```

## API Documentation

The FastAPI backend provides automatic interactive API documentation:

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Key Differences from Rails Application

### Authentication
- **Rails:** Doorkeeper OAuth2 provider, session-based auth
- **FastAPI:** JWT tokens with OAuth2 password flow

### Background Jobs
- **Rails:** Sidekiq with Redis
- **FastAPI:** Celery with Redis (to be implemented)

### File Uploads
- **Rails:** CarrierWave with S3
- **FastAPI:** To be implemented (boto3 for S3)

### Email
- **Rails:** Postmark, Mailchimp
- **FastAPI:** To be implemented

## Pending Migrations

### High Priority
1. Complete all model relationships
2. Implement stolen bike search with geolocation
3. Add file upload support (images, PDFs)
4. Implement email notifications
5. Add Stripe payment integration
6. Create remaining frontend pages

### Medium Priority
1. Celery background job system
2. Organization management interface
3. Impound record management
4. Hot sheets distribution
5. Ambassador program features

### Low Priority
1. POS integrations (Lightspeed, Ascend)
2. External registry integration
3. Twitter/social media integration
4. Advanced analytics and reporting

## Testing

### Backend (pytest)
```bash
cd backend
pytest
```

### Frontend (Jest)
```bash
cd frontend
npm test
```

## Deployment Considerations

1. **Environment Variables:** Ensure all secrets are properly configured
2. **Database:** Use managed PostgreSQL service (AWS RDS, etc.)
3. **Redis:** Required for Celery background jobs
4. **CORS:** Configure allowed origins for production
5. **SSL:** Use HTTPS in production
6. **Static Files:** Configure CDN for frontend assets
7. **File Storage:** Set up S3 or similar for uploads

## Migration Strategy

For a live migration from the Rails app:

1. **Parallel Run:** Run both systems side-by-side
2. **Data Migration:** Export data from Rails DB, import to new DB
3. **API Compatibility:** Maintain backward compatibility for mobile apps
4. **Gradual Rollout:** Migrate users in phases
5. **Rollback Plan:** Keep Rails app ready to reactivate if needed

## Support and Resources

- FastAPI Documentation: https://fastapi.tiangolo.com/
- Next.js Documentation: https://nextjs.org/docs
- SQLAlchemy Documentation: https://docs.sqlalchemy.org/
- Pydantic Documentation: https://docs.pydantic.dev/

## Notes

This migration maintains the core functionality of the Bike Index platform while modernizing the technology stack. The new architecture provides better type safety (TypeScript + Pydantic), automatic API documentation, and improved developer experience.
