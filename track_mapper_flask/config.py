# config.py
import os
BASE_DIR = os.path.abspath(os.path.dirname(__file__))

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
