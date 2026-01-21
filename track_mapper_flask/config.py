# config.py
import os
from dotenv import load_dotenv

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
load_dotenv(os.path.join(BASE_DIR, '.env'))

# Use DATABASE_URL when provided (e.g., production). If it starts with
# "postgres://" (Heroku style), convert to SQLAlchemy's expected
# "postgresql://" scheme.
_db_url = os.environ.get('DATABASE_URL')
if _db_url:
    if _db_url.startswith('postgres://'):
        _db_url = _db_url.replace('postgres://', 'postgresql://', 1)
    SQLALCHEMY_DATABASE_URI = _db_url
else:
    SQLALCHEMY_DATABASE_URI = "postgresql://localhost:5432/trackmapper"

SQLALCHEMY_TRACK_MODIFICATIONS = False
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'app', 'uploads')

# Storage Configuration
FILE_STORE_LOCATION = os.environ.get('FILE_STORE_LOCATION', 'LOCAL')
S3_BUCKET = os.environ.get('S3_BUCKET')
S3_ACCESS_KEY = os.environ.get('S3_ACCESS_KEY')
S3_SECRET_KEY = os.environ.get('S3_SECRET_KEY')
S3_REGION = os.environ.get('S3_REGION', 'us-east-1')
S3_ENDPOINT_URL = os.environ.get('S3_ENDPOINT_URL') # Optional for R2/other S3-compatible
