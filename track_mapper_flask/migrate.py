# track_mapper_flask/migrate.py
import os
import sqlite3
import uuid
import shutil
from app import create_app
from app.extensions import db
from app.models import User, Map, Activity, friend

# Configuration
SQLITE_DB = 'files.db'
UPLOAD_FOLDER = os.path.join('app', 'uploads')

def migrate():
    app = create_app()
    with app.app_context():
        # 1. Create tables in Postgres
        print("Creating tables in Postgres...")
        db.create_all()

        # 2. Connect to SQLite
        if not os.path.exists(SQLITE_DB):
            print(f"Error: {SQLITE_DB} not found.")
            return
        
        sl_conn = sqlite3.connect(SQLITE_DB)
        sl_cursor = sl_conn.cursor()

        # Mappings to keep track of old_id -> new_uuid
        user_map = {}
        map_id_map = {}
        activity_map = {}

        # --- MIGRATE USERS ---
        # print("Migrating Users...")
        # sl_cursor.execute("SELECT id, firstname, lastname, username, email, password_hash FROM user")
        # for row in sl_cursor.fetchall():
        #     old_id, fname, lname, uname, email, p_hash = row
        #     new_uuid = uuid.uuid4()
        #     user_map[old_id] = new_uuid
            
        #     u = User(
        #         id=new_uuid,
        #         firstname=fname,
        #         lastname=lname,
        #         username=uname,
        #         email=email,
        #         password_hash=p_hash
        #     )
        #     db.session.add(u)
        
        # --- MIGRATE FRIENDSHIPS ---
        # print("Migrating Friendships...")
        # sl_cursor.execute("SELECT user_id, friend_id FROM friend")
        # for row in sl_cursor.fetchall():
        #     u_id, f_id = row
        #     if u_id in user_map and f_id in user_map:
        #         # Insert directly into the secondary table
        #         db.session.execute(
        #             friend.insert().values(
        #                 user_id=user_map[u_id],
        #                 friend_id=user_map[f_id]
        #             )
        #         )

        # --- MIGRATE MAPS ---
        # print("Migrating Maps and renaming files...")
        # sl_cursor.execute("SELECT id, title, description, image_path, user_id, latitude, longitude, num_points, uploaded_at FROM map")
        # for row in sl_cursor.fetchall():
        #     old_id, title, desc, img_path, u_id, lat, lon, pts, uploaded_at = row
        #     new_uuid = uuid.uuid4()
        #     map_id_map[old_id] = new_uuid

        #     # Handle file renaming
        #     # image_1.jpg -> image_<uuid>.jpg
        #     new_img_name = f"image_{new_uuid}.jpg"
        #     old_img_path = os.path.join(UPLOAD_FOLDER, f"image_{old_id}.jpg")
        #     new_img_path = os.path.join(UPLOAD_FOLDER, new_img_name)
            
        #     if os.path.exists(old_img_path):
        #         shutil.move(old_img_path, new_img_path)
            
        #     # points_1.json -> points_<uuid>.json
        #     old_pts_path = os.path.join(UPLOAD_FOLDER, f"points_{old_id}.json")
        #     new_pts_path = os.path.join(UPLOAD_FOLDER, f"points_{new_uuid}.json")
        #     if os.path.exists(old_pts_path):
        #         shutil.move(old_pts_path, new_pts_path)

        #     m = Map(
        #         id=new_uuid,
        #         title=title,
        #         description=desc,
        #         image_path=new_img_name,
        #         user_id=user_map[u_id],
        #         latitude=lat,
        #         longitude=lon,
        #         num_points=pts,
        #         uploaded_at=uploaded_at # SQLite returns string, SQLAlchemy will parse if possible
        #     )
        #     db.session.add(m)

        # --- MIGRATE ACTIVITIES ---
        print("Migrating Activities and renaming GPX files...")
        sl_cursor.execute("SELECT id, title, description, user_id, map_id, created_at, distance, elapsed_time FROM activity")
        for row in sl_cursor.fetchall():
            old_id, title, desc, u_id, m_id, created_at, dist, elapsed = row
            new_uuid = uuid.uuid4()
            
            # gpx_1.gpx -> gpx_<uuid>.gpx
            old_gpx_path = os.path.join(UPLOAD_FOLDER, f"gpx_{old_id}.gpx")
            new_gpx_path = os.path.join(UPLOAD_FOLDER, f"gpx_{new_uuid}.gpx")
            if os.path.exists(old_gpx_path):
                shutil.move(old_gpx_path, new_gpx_path)

            a = Activity(
                id=new_uuid,
                title=title,
                description=desc,
                user_id=user_map[u_id],
                map_id=map_id_map.get(m_id) if m_id else None,
                created_at=created_at,
                distance=dist,
                elapsed_time=elapsed
            )
            db.session.add(a)

        db.session.commit()
        sl_conn.close()
        print("✅ Migration complete! SQLite data moved to Postgres and files renamed.")

if __name__ == "__main__":
    migrate()
