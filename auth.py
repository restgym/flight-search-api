"""
Flight Search API - Authentication script of the proxy
Signs in as the administrator registered by entrypoint.sh, adds its access token to every request (except those to the
authentication endpoints), and signs in again before the token expires (30 minutes). A 401 does not make it sign in
again: the tools cannot invalidate the tokens of the proxy, since a logout with one of them is blocked (471), however it
is written, so a 401 is an answer of the API, not a lost session
"""
import base64
import json
import posixpath
import re
import time
from urllib.parse import unquote

import requests
from mitmproxy import ctx, http

LOGIN_URL = "http://localhost:8080/api/v1/authentication/user/login"
CREDENTIALS = {"email": "restgym-proxy@restgym.com", "password": "Password123!"}     # registered by entrypoint.sh
RENEW_BEFORE_SECONDS = 60       # sign in again this long before the token expires
RETRY_AFTER_SECONDS = 5         # after a failed sign-in, wait this long before trying again
LOGOUT_PATH = "/api/v1/authentication/user/logout"
SEGMENT = re.compile(r"[A-Za-z0-9_+/=-]{16,}")              # text in base64url or base64, e.g., the payload of a JWT


# The path as the API reads it: without the query and the parameters of the segments (;...), decoded once, with . and ..
# segments resolved, without repeated or trailing slashes
def normalize_path(path):
    path = path.split('?', 1)[0]
    path = '/'.join(segment.split(';', 1)[0] for segment in path.split('/'))
    path = posixpath.normpath('/' + unquote(path))
    return '/' + path.lstrip('/')


# The id (jti) in the payload of a JWT, or None
def token_id(payload):
    try:
        payload = payload.replace('+', '-').replace('/', '_').rstrip('=')
        return json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4))).get("jti")
    except Exception:
        return None


# Every string (keys and values) of a JSON value
def json_strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, item in value.items():
            yield key
            yield from json_strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from json_strings(item)


# The texts in which the API may find tokens: the body as text, and the strings of the JSON in it, read as Jackson reads
# them (escapes such as e decoded, in the charset of the Content-Type or the one detected, only the first JSON value)
def body_texts(request):
    raw = request.get_content(strict=False) or b""
    texts = [raw.decode("latin-1")]
    charset = re.search(r"charset=[\"']?([\w.:-]+)", request.headers.get("Content-Type", ""), re.I)
    for encoding in ([charset.group(1)] if charset else []) + [json.detect_encoding(raw)]:
        try:
            text = raw.decode(encoding).lstrip("﻿ \t\r\n")
            texts.extend(json_strings(json.JSONDecoder().raw_decode(text)[0]))
        except Exception:
            pass
    return texts


class Authenticate:
    def __init__(self):
        self.token = None
        self.expires_at = 0         # epoch seconds (accessTokenExpiresAt of the API)
        self.failed_at = 0
        self.own_ids = set()        # ids (jti) of every access and refresh token obtained: earlier ones stay valid until they expire

    def sign_in(self):
        """Sign in and keep the access token and its expiration"""
        if time.time() - self.failed_at < RETRY_AFTER_SECONDS:
            return
        try:
            response = requests.post(LOGIN_URL, json=CREDENTIALS, timeout=30)
            body = response.json().get("response") or {}
            self.token = body["accessToken"]
            self.expires_at = body.get("accessTokenExpiresAt") or time.time() + 30 * 60
            for token in (self.token, body.get("refreshToken")):
                parts = (token or "").split(".")
                if len(parts) == 3 and token_id(parts[1]):
                    self.own_ids.add(token_id(parts[1]))
            ctx.log.info(f"[AUTH] Signed in as {CREDENTIALS['email']}: the token expires at {time.ctime(self.expires_at)}")
        except Exception as e:
            self.token = None
            self.failed_at = time.time()
            ctx.log.warn(f"[AUTH] Sign-in failed: {e}")

    def revokes_own_token(self, request):
        """Whether the body contains a token with the id of a token of the proxy (the logout invalidates tokens by id)"""
        return any(token_id(segment) in self.own_ids for text in body_texts(request) for segment in SEGMENT.findall(text))

    def request(self, flow):
        # The logout invalidates the tokens in its body, whoever sends it: a logout with a token of the proxy is answered
        # with 471 and never forwarded to the API (the tools never see these tokens, so this is only a safety net)
        if (flow.request.method.upper() == "POST" and normalize_path(flow.request.path) == LOGOUT_PATH
                and self.revokes_own_token(flow.request)):
            flow.response = http.HTTPResponse.make(
                471,
                json.dumps({"message": "Blocked by RESTgym: the request would end the session of the proxy (logout with its token)"}),
                {"Content-Type": "application/json", "X-RESTgym-Blocked": "true"})
            flow.response.reason = "Blocked by RESTgym"
            return

        # The authentication endpoints are left as the tools send them
        if "/api/v1/authentication/" in flow.request.path:
            return

        if self.token is None or time.time() >= self.expires_at - RENEW_BEFORE_SECONDS:
            self.sign_in()

        if self.token:
            flow.request.headers["Authorization"] = "Bearer " + self.token


addons = [Authenticate()]
