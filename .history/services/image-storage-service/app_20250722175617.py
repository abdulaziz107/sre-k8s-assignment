import os
import uuid
import jwt
import psycopg2
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
CORS(app)

# Bilingual messages
messages = {
    'en': {
        'imageServiceRunning': 'Image Storage Service is running',
        'healthy': 'healthy',
        'imageStorageService': 'image-storage-service',
        'authHeaderRequired': 'Authorization header required',
        'invalidToken': 'Invalid token',
        'failedToListImages': 'Failed to list images',
        'failedToGetStats': 'Failed to get stats',
        'uploadReady': 'Upload endpoint ready',
        'implemented': 'implemented'
    },
    'ar': {
        'imageServiceRunning': 'خدمة تخزين الصور تعمل',
        'healthy': 'صحي',
        'imageStorageService': 'خدمة-تخزين-الصور',
        'authHeaderRequired': 'رأس التفويض مطلوب',
        'invalidToken': 'رمز غير صحيح',
        'failedToListImages': 'فشل في قائمة الصور',
        'failedToGetStats': 'فشل في الحصول على الإحصائيات',
        'uploadReady': 'نقطة رفع جاهزة',
        'implemented': 'مفعل'
    }
}

def get_message(request, key):
    """Get message based on Accept-Language header"""
    accept_language = request.headers.get('Accept-Language', 'en')
    lang = 'ar' if accept_language.startswith('ar') else 'en'
    return messages[lang].get(key, messages['en'].get(key))

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'HTTP request latency', ['method', 'endpoint'])
ACTIVE_REQUESTS = Gauge('active_requests', 'Number of active requests')

# Configuration
JWT_SECRET = os.getenv('JWT_SECRET', 'your-secret-key')
DB_HOST = os.getenv('DB_HOST', 'postgresql')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'image_db')
DB_USER = os.getenv('DB_USER', 'image_user')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'image_password')

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )

def init_database():
    conn = get_db_connection()
    cur = conn.cursor()
    
    cur.execute('''
        CREATE TABLE IF NOT EXISTS images (
            id SERIAL PRIMARY KEY,
            filename VARCHAR(255) NOT NULL,
            original_name VARCHAR(255) NOT NULL,
            content_type VARCHAR(100) NOT NULL,
            size BIGINT NOT NULL,
            user_id INTEGER NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    conn.commit()
    cur.close()
    conn.close()

def verify_jwt_token(token):
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

def auth_required(f):
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': get_message(request, 'authHeaderRequired')}), 401
        
        token = auth_header.split(' ')[1]
        payload = verify_jwt_token(token)
        if not payload:
            return jsonify({'error': get_message(request, 'invalidToken')}), 401
        
        request.user_id = payload.get('user_id')
        request.username = payload.get('username')
        return f(*args, **kwargs)
    decorated_function.__name__ = f.__name__ + '_decorated'
    return decorated_function

@app.before_request
def before_request():
    ACTIVE_REQUESTS.inc()

@app.after_request
def after_request(response):
    ACTIVE_REQUESTS.dec()
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.endpoint,
        status=response.status_code
    ).inc()
    return response

@app.route('/health')
def health_check():
    return jsonify({
        'status': get_message(request, 'healthy'),
        'service': get_message(request, 'imageStorageService'),
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/')
def root():
    return jsonify({
        'message': get_message(request, 'imageServiceRunning'),
        'version': '1.0.0',
        'endpoints': [
            '/health',
            '/metrics',
            '/api/images',
            '/api/upload'
        ]
    })

@app.route('/api/images', methods=['GET'])
@auth_required
def list_images_route():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        cur.execute('''
            SELECT id, filename, original_name, content_type, size, created_at
            FROM images
            WHERE user_id = %s
            ORDER BY created_at DESC
        ''', (request.user_id,))
        
        images = []
        for row in cur.fetchall():
            images.append({
                'id': row[0],
                'filename': row[1],
                'original_name': row[2],
                'content_type': row[3],
                'size': row[4],
                'created_at': row[5].isoformat()
            })
        
        cur.close()
        conn.close()
        
        return jsonify({'images': images}), 200
        
    except Exception as e:
        return jsonify({'error': f"{get_message(request, 'failedToListImages')}: {str(e)}"}), 500

@app.route('/api/upload', methods=['POST'])
@auth_required
def upload_image_route():
    return jsonify({
        'message': get_message(request, 'uploadReady'),
        'status': get_message(request, 'implemented')
    }), 200

@app.route('/api/stats', methods=['GET'])
@auth_required
def get_stats_route():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        cur.execute('''
            SELECT COUNT(*) as total_images, SUM(size) as total_size
            FROM images
            WHERE user_id = %s
        ''', (request.user_id,))
        
        result = cur.fetchone()
        total_images = result[0] or 0
        total_size = result[1] or 0
        
        cur.close()
        conn.close()
        
        return jsonify({
            'total_images': total_images,
            'total_size_bytes': total_size,
            'total_size_mb': round(total_size / (1024 * 1024), 2)
        }), 200
        
    except Exception as e:
        return jsonify({'error': f"{get_message(request, 'failedToGetStats')}: {str(e)}"}), 500

if __name__ == '__main__':
    # Initialize database
    init_database()
    
    port = int(os.getenv('PORT', 3003))
    app.run(host='0.0.0.0', port=port, debug=False) 