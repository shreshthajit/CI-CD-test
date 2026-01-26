from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        "message": "Welcome to Python Backend API",
        "status": "healthy",
        "version": "1.0.0"
    })

@app.route('/health')
def health():
    return jsonify({
        "status": "healthy",
        "service": "python-backend"
    })

@app.route('/api/info')
def info():
    return jsonify({
        "app": "Python Backend",
        "environment": os.getenv("ENVIRONMENT", "development"),
        "port": 8080
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)

