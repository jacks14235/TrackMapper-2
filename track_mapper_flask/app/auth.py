from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from .extensions import db
from .models import User

auth_bp = Blueprint('auth', __name__)

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


