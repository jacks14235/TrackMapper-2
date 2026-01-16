from app.models import db, User, Map, Activity, friend
from faker import Faker
import random
from sqlalchemy.exc import IntegrityError
from datetime import datetime, timezone, timedelta
import os

fake = Faker()
Faker.seed(777)

NUM_USERS = 10
MAPS_PER_USER = 3
ACTIVITIES_PER_USER = 4
MAX_FRIENDS_PER_USER = 3

def copy_real_maps():
    os.system("cp ../TrackMapper/whiteface.json app/uploads/points_1.json")
    os.system("cp ../TrackMapper/Assets.xcassets/Whiteface.imageset/Whiteface.jpg app/uploads/image_1.jpg")
    os.system("cp ../TrackMapper/shawnee.json app/uploads/points_2.json")
    os.system("cp ../TrackMapper/Assets.xcassets/shawnee_map.imageset/shawnee_map.jpg app/uploads/image_2.jpg")

    map = Map(
        title="Whiteface",
        description="Whiteface Mountain",
        image_path="image_1.jpg",
        latitude=41.7000,
        longitude=-73.9000,
        user_id=1,
        num_points=50,
    )
    db.session.add(map)
    map = Map(
        title="Shawnee",
        description="Shawnee Mountain",
        image_path="image_2.jpg",
        latitude=41.7000,
        longitude=-73.9000,
        user_id=1,
        num_points=27,
    )
    db.session.add(map)
    db.session.commit()

def create_users():
    users = []
    for _ in range(NUM_USERS):
        user = User(
            firstname=fake.first_name(),
            lastname=fake.last_name(),
            username=fake.unique.user_name(),
            email=fake.unique.email()
        )
        db.session.add(user)
        users.append(user)
    # Commit so IDs are assigned, then set passwords based on those IDs
    db.session.commit()

    from werkzeug.security import generate_password_hash
    for u in users:
        # password is user_<id>
        password = f"user_{u.id}"
        print(f"Setting password for {u.username} to {password}")
        u.password_hash = generate_password_hash(password)
    db.session.commit()
    return users

def create_friendships(users):
    for user in users:
        possible_friends = [u for u in users if u != user]
        friends = random.sample(possible_friends, k=min(MAX_FRIENDS_PER_USER, len(possible_friends)))
        for friend in friends:
            if friend not in user.friends:
                user.friends.append(friend)
    db.session.commit()

def create_maps(users):
    all_maps = []
    for user in users:
        for _ in range(MAPS_PER_USER):
            lon = fake.latitude()
            lat = fake.longitude()
            map = Map(
                title=fake.sentence(nb_words=3),
                description=fake.text(max_nb_chars=100),
                image_path=f"images/{fake.uuid4()}.jpg",
                latitude=lat,
                longitude=lon,
                num_points=random.randint(50, 500),
                user=user
            )
            db.session.add(map)
            db.session.flush()  # Ensure the map object gets an ID
            all_maps.append(map)
            file_number = random.randint(1, 3)
            image_file = f'app/uploads_old/image_{file_number}.jpg'
            points_files = [f'app/uploads_old/points_{file_number}.json']
            new_image_path = os.path.join('app', 'uploads', f'image_{map.id}.jpg')
            if not os.path.exists(new_image_path):
                with open(image_file, 'rb') as fsrc:
                    with open(new_image_path, 'wb') as fdst:
                        fdst.write(fsrc.read())
            points_file = random.choice(points_files)
            new_points_file_path = os.path.join('app', 'uploads', f'points_{map.id}.json')
            if not os.path.exists(new_points_file_path):
                with open(points_file, 'rb') as fsrc:
                    with open(new_points_file_path, 'wb') as fdst:
                        fdst.write(fsrc.read())
    db.session.commit()
    return all_maps

gpx_files = [f'app/uploads_old/gpx_{i}.gpx' for i in range(1,4)]
def create_activities(users, maps_by_user):
    for user in users:
        maps = maps_by_user[user.id]
        for _ in range(ACTIVITIES_PER_USER):
            # choose time in the last 30 days
            created = datetime.now(timezone.utc) - timedelta(days=random.randint(0, 30))
            activity = Activity(
                title=fake.sentence(nb_words=3),
                description=fake.text(max_nb_chars=100),
                user=user,
                map_id=random.choice(maps).id if maps and random.random() < 0.7 else None,  # 70% chance to attach to a map
                created_at=created,
                distance=random.random() * 20000, # random distance in meters
                elapsed_time=random.randint(3600, 7200),  # random duration between 1 and 2 hours
            )
            db.session.add(activity)
            file = random.choice(gpx_files)
            # copy the file and rename it based on the activity ID
            new_file_path = os.path.join('app', 'uploads', f'{activity.id}.gpx')
            if not os.path.exists(new_file_path):
                with open(file, 'rb') as fsrc:
                    with open(new_file_path, 'wb') as fdst:
                        fdst.write(fsrc.read())
            
            
    db.session.commit()

def run():
    print("Creating users...")
    users = create_users()
    copy_real_maps()
    print("Creating friendships...")
    create_friendships(users)

    print("Creating maps...")
    all_maps = create_maps(users)
    maps_by_user = {}
    for map in all_maps:
        maps_by_user.setdefault(map.user_id, []).append(map)

    print("Creating activities...")
    create_activities(users, maps_by_user)

    print("✅ Done seeding the database.")

if __name__ == "__main__":
    from app import create_app
    app = create_app()
    with app.app_context():
        try:
            db.drop_all()
            db.create_all()
            run()
        except IntegrityError as e:
            db.session.rollback()
            print("❌ Integrity Error:", e)
