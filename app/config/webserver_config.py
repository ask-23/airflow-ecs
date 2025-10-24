# -*- coding: utf-8 -*-
# Airflow Webserver Configuration

import os
from airflow.www.fab_security.manager import AUTH_OAUTH
from flask_appbuilder.security.manager import AUTH_DB

# Flask-AppBuilder Configuration
basedir = os.path.abspath(os.path.dirname(__file__))

# Auth type - Use AUTH_OAUTH for SSO via ALB
AUTH_TYPE = AUTH_DB  # Change to AUTH_OAUTH when SSO is configured

# Security settings
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = 'Lax'
WTF_CSRF_ENABLED = True

# Logging
LOGGING_LEVEL = "INFO"

# Health endpoint
HEALTH_CHECK_ENDPOINT = "/health"
