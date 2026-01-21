from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from .extensions import db
from .models import User

auth_bp = Blueprint('auth', __name__)


def _unique_username(base: str) -> str:
    base = (base or "user").strip()
    candidate = base
    i = 1
    while User.query.filter_by(username=candidate).first():
        candidate = f"{base}{i}"
        i += 1
    return candidate

@auth_bp.route('/auth/register', methods=['POST'])
def register():
    data = request.get_json() or {}
    email = data.get('email')
    password = data.get('password')
    firstname = data.get('firstname', '')
    lastname = data.get('lastname', '')
    username = data.get('username') or (email.split('@')[0] if email else None)

    if not email or not password:
        return jsonify(error='email and password required'), 400

    if User.query.filter((User.email == email) | (User.username == username)).first():
        return jsonify(error='user already exists'), 409

    u = User(
        email=email,
        username=username,
        firstname=firstname or 'First',
        lastname=lastname or 'Last',
        password_hash=generate_password_hash(password)
    )
    db.session.add(u)
    db.session.commit()

    # For simplicity, return a fake token and user payload
    token = f"token-{u.id}"
    return jsonify(token=token, user=u.to_dict()), 201

@auth_bp.route('/auth/login', methods=['POST'])
def login():
    data = request.get_json() or {}
    email = data.get('email')
    password = data.get('password')
    if not email or not password:
        return jsonify(error='email and password required'), 400

    u = User.query.filter_by(email=email).first()
    if not u or not check_password_hash(u.password_hash, password):
        return jsonify(error='invalid credentials'), 401

    token = f"token-{u.id}"
    return jsonify(token=token, user=u.to_dict())


@auth_bp.route('/auth/google', methods=['POST'])
def google_login():
    print("google_login")
    data = request.get_json() or {}
    email = data.get('email')
    google_id = data.get('google_id')
    print("email", email)
    print("google_id", google_id)
    firstname = data.get('firstname', '')
    lastname = data.get('lastname', '')
    username = data.get('username') or (email.split('@')[0] if email else None)

    if not email or not google_id:
        return jsonify(error='email and google_id required'), 400

    # 1) Lookup by google_id first
    u = User.query.filter_by(google_id=google_id).first()

    # 2) Fallback to email, update google_id if needed
    if not u:
        u = User.query.filter_by(email=email).first()
        if u and u.google_id != google_id:
            u.google_id = google_id

    # 3) Create new user if still not found
    if not u:
        u = User(
            email=email,
            username=_unique_username(username),
            firstname=firstname or 'First',
            lastname=lastname or 'Last',
            google_id=google_id,
            password_hash=""
        )
        db.session.add(u)

    db.session.commit()
    token = f"token-{u.id}"
    return jsonify(token=token, user=u.to_dict())

