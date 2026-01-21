import os
import boto3
from flask import current_app, send_from_directory
from botocore.exceptions import ClientError

def get_s3_client():
    kwargs = {
        'service_name': 's3',
        'aws_access_key_id': current_app.config['S3_ACCESS_KEY'],
        'aws_secret_access_key': current_app.config['S3_SECRET_KEY'],
        'region_name': current_app.config['S3_REGION']
    }
    
    endpoint = current_app.config.get('S3_ENDPOINT_URL')
    if endpoint and endpoint.strip():
        kwargs['endpoint_url'] = endpoint
        print(f"Getting S3 client with endpoint: {endpoint}")
    else:
        print("Getting S3 client using default AWS endpoint")
        
    return boto3.client(**kwargs)

def save_file(file_obj, folder, filename):
    """
    Saves a file to either S3 or LOCAL storage based on configuration.
    folder: Subfolder (e.g., 'images', 'activities', 'points')
    file_obj: Can be a file-like object or bytes.
    filename: The name to save the file as.
    """
    storage_type = current_app.config.get('FILE_STORE_LOCATION', 'LOCAL').upper()
    full_filename = f"{folder}/{filename}"
    print(f"Saving file to {storage_type}: {full_filename}")
    if storage_type == 'S3':
        s3 = get_s3_client()
        bucket = current_app.config['S3_BUCKET']
        try:
            if isinstance(file_obj, bytes):
                s3.put_object(Bucket=bucket, Key=full_filename, Body=file_obj)
            else:
                s3.upload_fileobj(file_obj, bucket, full_filename)
            return True
        except ClientError as e:
            print(f"S3 Upload Error: {e}")
            return False
    else:
        # LOCAL storage
        upload_dir = os.path.join(current_app.config['UPLOAD_FOLDER'], folder)
        os.makedirs(upload_dir, exist_ok=True)
        path = os.path.join(upload_dir, filename)
        
        if isinstance(file_obj, bytes):
            with open(path, 'wb') as f:
                f.write(file_obj)
        else:
            file_obj.save(path)
        return True

def delete_file(folder, filename):
    """
    Deletes a file from either S3 or LOCAL storage.
    """
    storage_type = current_app.config.get('FILE_STORE_LOCATION', 'LOCAL').upper()
    full_filename = f"{folder}/{filename}"
    
    if storage_type == 'S3':
        s3 = get_s3_client()
        bucket = current_app.config['S3_BUCKET']
        try:
            s3.delete_object(Bucket=bucket, Key=full_filename)
            return True
        except ClientError as e:
            print(f"S3 Delete Error: {e}")
            return False
    else:
        upload_dir = os.path.join(current_app.config['UPLOAD_FOLDER'], folder)
        path = os.path.join(upload_dir, filename)
        if os.path.exists(path):
            os.remove(path)
            return True
        return False

def get_file_response(folder, filename):
    """
    Returns a response to serve the file.
    """
    storage_type = current_app.config.get('FILE_STORE_LOCATION', 'LOCAL').upper()
    full_filename = f"{folder}/{filename}"
    
    if storage_type == 'S3':
        bucket = current_app.config['S3_BUCKET']
        s3 = get_s3_client()
        try:
            url = s3.generate_presigned_url('get_object',
                                            Params={'Bucket': bucket, 'Key': full_filename},
                                            ExpiresIn=3600)
            from flask import redirect
            return redirect(url)
        except ClientError as e:
            print(f"S3 URL Error: {e}")
            return None
    else:
        upload_dir = os.path.join(current_app.config['UPLOAD_FOLDER'], folder)
        return send_from_directory(upload_dir, filename, as_attachment=True)
